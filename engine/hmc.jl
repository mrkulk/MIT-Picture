using Debug
using Distributions

@debug function set_chobject(DB, name , q, q_len)
	DB["RC"][name]["X"] = q

	if q_len == 1
		set!(DB["RC"][name]["ch_object"],0,q)
	else
		for i=1:q_len
			set!(DB["RC"][name]["ch_object"],i-1,q[i]) #i-1 because python starts with 0 index
		end	
	end

	#add new logl
	theta_d = DB["RC"][name]["theta_c"]
	erp = DB["RC"][name]["ERP"]
	dist = ERP_CREATE(erp, theta_d)
	DB["RC"][name]["logl"] = logscore_erp(dist, q, theta_d)

	return DB
end

@debug function compute_gradU( name_indices, q, q_len)
	for name in collect(keys(name_indices))
		indxs = name_indices[name]
		params.CURRENT_TRACE = set_chobject(params.CURRENT_TRACE, name, q[indxs], length(indxs))
	end
	trace_update(params.TAST)#for propagation

	final_gradient = zeros(q_len)

	for name in collect(keys(name_indices))
		rvs = params.CURRENT_TRACE["RC"][name]["ch_object"]
		grad_U = pycall(params.CURRENT_TRACE["tape_logl"]["dr_wrt"],PyAny,rvs);
		if typeof(grad_U) == PyObject
			grad_U = convert(PyAny,grad_U["A"]);
		end
		grad_U = sum(grad_U,1)/size(grad_U,1);
		if haskey(params.CURRENT_TRACE["RC"][name],"ch_lpdf")#params.CURRENT_TRACE["RC"][name]["ERP"] == Normal
			grad_P = pycall(params.CURRENT_TRACE["RC"][name]["ch_lpdf"]["dr_wrt"],PyAny,rvs);
			if typeof(grad_P) == PyObject
				grad_P = convert(PyAny,grad_P["A"]);
			end
			grad_P = sum(grad_P,1)/size(grad_P,1);
			grad_U += grad_P
		end
		# println("H GRAD:", grad_U)

		indxs = name_indices[name]
		final_gradient[indxs] = grad_U[:]
	end


	return final_gradient
end

function isBounded(erp,theta)
	if erp == Uniform
		return true, theta[1], theta[2]
	elseif erp == Beta
		return true, 0, 1
	end
	return false, NaN, NaN
end

@debug function hmc_propose(names, debug_callback)

	params.CURRENT_TRACE = deepcopy(params.TRACE)
	# trace_update(params.TAST)

	epsilon = 0.1 #0.1
	LEAP_FROG = rand(DiscreteUniform(5,10)) #10-20

	q_len = 0
	for name in names
		tmp = np.shape(params.CURRENT_TRACE["RC"][name]["ch_object"])
		if tmp == (1,)
			tmp = 1
		else
			tmp = tmp[1]
		end
		q_len += tmp
	end

	current_q = 0
	name_indices = Dict()
	startid = 1; endid = 0;

	for name in names
		endid += length(params.CURRENT_TRACE["RC"][name]["X"])
		name_indices[name] = startid:endid
		startid = endid + 1

		if current_q == 0
			current_q = deepcopy(params.CURRENT_TRACE["RC"][name]["X"])
		else
			current_q = append!(current_q,deepcopy(params.CURRENT_TRACE["RC"][name]["X"]))
		end
	end

	q = deepcopy(current_q)
	p = rand(Normal(0,1,),1,length(q))[:]
	current_p = deepcopy(p)

	# ########### DEBUG ############
	# q = q + rand(1,3)
	# aa=compute_gradU(DB, name, q)
	# println(aa)
	
	# params.CURRENT_TRACE = set_chobject(params.CURRENT_TRACE, name, q, q_len)
	# trace_update(params.TAST)
	# DB = deepcopy(params.CURRENT_TRACE)

	# return DB
	# ###############################

	#Make half step for momentum at the beginning

	p = p - epsilon * compute_gradU(name_indices, q, q_len)


	#Alternate full steps for position and momentum
	for i = 1:LEAP_FROG
		q = q + epsilon * p

		for name in names
			handle_constraints, llimit, ulimit = isBounded(params.CURRENT_TRACE["RC"][name]["ERP"], params.CURRENT_TRACE["RC"][name]["theta_c"])
			if handle_constraints
				indxs = name_indices[name]
				phat = deepcopy(p[indxs])
				qhat = deepcopy(q[indxs])
				for ii = 1:length(qhat)
					while qhat[ii] > ulimit || qhat[ii] < llimit
						if qhat[ii] > ulimit
							qhat[ii] = ulimit - (qhat[ii] - ulimit)
							phat[ii] = -phat[ii]
						elseif qhat[ii] < llimit
							qhat[ii] = llimit + (llimit - qhat[ii])
							phat[ii] = -phat[ii]
						end
					end
					q[indxs[1]+ii-1] = deepcopy(qhat[ii]); p[indxs[1]+ii-1] = deepcopy(phat[ii])
				end
			end
		end

		#Make full step for the momentum, except at the end of trajectory
		if i != LEAP_FROG
			p = p - epsilon*compute_gradU(name_indices, q, q_len)
		end
	end

	#Make a half step for momentum at the end
	p = p - epsilon*compute_gradU(name_indices,q, q_len)*0.5
	p = -p 

	#Evaluate potential and kinect energy
	#DB = set_chobject(DB, name, current_q, q_len)
	#params.CURRENT_TRACE = deepcopy(DB)
	for name in names
		indxs = name_indices[name]
		params.CURRENT_TRACE = set_chobject(params.CURRENT_TRACE, name, current_q[indxs], length(indxs))
	end
	trace_update(params.TAST)
	# CUR_TRACE = deepcopy(params.CURRENT_TRACE)
	current_U = -params.CURRENT_TRACE["ll"]
	current_K = sum(current_p.*current_p)/2.0
	old_rc_cnt = length(params.CURRENT_TRACE["RC"])


	#DB = set_chobject(DB, name, q, q_len)
	#params.CURRENT_TRACE = deepcopy(DB)
	for name in names
		indxs = name_indices[name]
		params.CURRENT_TRACE = set_chobject(params.CURRENT_TRACE, name,  q[indxs], length(indxs))
	end
	trace_update(params.TAST)
	# NEW_TRACE = deepcopy(params.CURRENT_TRACE)
	proposed_U = -params.CURRENT_TRACE["ll"]; ll_fresh = params.CURRENT_TRACE["ll_fresh"]; ll_stale = params.CURRENT_TRACE["ll_stale"]
	proposed_K = sum(p.*p)/2.0
	new_rc_cnt = length(params.CURRENT_TRACE["RC"])

	if isnan(proposed_U)
		proposed_U = 1e200
	end

	#accept or reject
	if rand() < exp(current_U - proposed_U + current_K - proposed_K + log(old_rc_cnt) - log(new_rc_cnt) + ll_stale - ll_fresh)
		#accept
		#DB = deepcopy(NEW_TRACE)
		for name in names
			indxs = name_indices[name]
			params.CURRENT_TRACE = set_chobject(params.CURRENT_TRACE, name, q[indxs], length(indxs))
		end
		trace_update(params.TAST)
		debug_callback(params.CURRENT_TRACE)
		println("ACCEPT")
		# return NEW_TRACE
		return params.CURRENT_TRACE#deepcopy(params.CURRENT_TRACE)
	else
		for name in names
			indxs = name_indices[name]
			params.CURRENT_TRACE = set_chobject(params.CURRENT_TRACE, name, current_q[indxs], length(indxs))
		end
		trace_update(params.TAST)
		println("REJECTED")
		#reject
		#DB = deepcopy(CUR_TRACE)
		# return CUR_TRACE
		return params.CURRENT_TRACE#deepcopy(params.CURRENT_TRACE)
	end
end




