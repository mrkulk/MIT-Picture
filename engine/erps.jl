
using PyCall
@pyimport numpy.random as npr #there's something wrong with MvNormal. No other need for numpy

function observe(id, distribution, DATA)
	flag=false
	logl = 0

	if haskey(params.CURRENT_TRACE["observe"],id) == true
		if params.CURRENT_TRACE["observe"][id]["distribution"] == distribution && params.CURRENT_TRACE["observe"][id]["data"] == DATA
			logl = params.CURRENT_TRACE["observe"][id]["logl"]
		else
			flag = true
		end
	else
		flag = true
	end

	if flag
		logl = sum(logpdf(distribution, DATA))
		params.CURRENT_TRACE["observe"][id]=Dict()
		params.CURRENT_TRACE["observe"][id]["logl"]=logl
		params.CURRENT_TRACE["observe"][id]["distribution"]=distribution
		params.CURRENT_TRACE["observe"][id]["data"]=DATA
	end
	params.CURRENT_TRACE["ll"] += logl
end


function observe_normal_cf(id, distribution, DATA)
	logl = 1/length(D) * sum(logpdf(distribution, DATA))
	params.CURRENT_TRACE["observe"][id]=Dict()
	params.CURRENT_TRACE["observe"][id]["logl"]=logl
	params.CURRENT_TRACE["observe"][id]["distribution"]=distribution
	params.CURRENT_TRACE["observe"][id]["data"]=DATA
	params.CURRENT_TRACE["ll"] += logl
end


function observe_NoisyGaussianPyramid(rendering, obs_gpr)	

	#difference = pycall(chumpy_lib["subtract"], PyAny, rendering, observed)
	#gpr = odr.gaussian_pyramid(difference,n_levels=6,as_list=true)# gpr = gpr[4:]

	gpr = odr.gaussian_pyramid(rendering,n_levels=6,as_list=true)# gpr = gpr[4:]
	#normal pdf
	mu = 0; sigma = 0.001
	U_Potential=NaN
	# XVALS=NaN
	for id = 1:length(gpr)
		### CORRECT ###
		######### Likelihood ##########
		t0=pycall(chumpy_lib["ravel"],PyAny,gpr[id])
		#t1=pycall(chumpy_lib["subtract"],PyAny,t0,mu);
		t1=pycall(chumpy_lib["subtract"],PyAny,t0,obs_gpr[id]);
		t2=pycall(chumpy_lib["multiply"],PyAny,t1,t1);
		t3=pycall(chumpy_lib["multiply"],PyAny,t2,-1.0/(2*sigma*sigma));
		t4=pycall(chumpy_lib["subtract"],PyAny,t3,log(sqrt(2*pi*sigma*sigma)));
		######### Prior -- add from tape object ##########
		## TODO - prior from tape in main program 

		logl_layer=pycall(chumpy_lib["multiply"],PyAny,t4,-1); #Potential energy is negative of posterior

		if id == 1
			U_Potential = logl_layer
		else
			U_Potential = ch.concatenate((U_Potential, logl_layer))
		end

		# plt.imshow(gpr[id]);plt.show(block=true)
		# @bp
	end

	params.CURRENT_TRACE["tape_logl"] = U_Potential
	params.CURRENT_TRACE["ll"] += -sum(PyJCast(U_Potential)) #negative because we want logl and U_Potential is negative log-posterior
	
	# rvs = params.CURRENT_TRACE["RC"]["G1"]["ch_object"]

	# grad_U = pycall(U_Potential["dr_wrt"],PyAny,rvs);
	# grad_U = convert(PyAny,grad_U["A"]);
	# grad_U = sum(grad_U,1)/size(grad_U,1);

	# print("GRAD: ")
	# for i=1:length(grad_U)
	# 	print(grad_U[i],"	  ")
	# end
	# println()

	# return grad_U
end


function logscore_erp(ERP, X, theta_c)
	if ERP == "NPR_MVN" #there's something wrong with julia's mvn
		return 0#sum(-0.5*X'*inv(theta_c[2])*X-0.5*log(det(theta_c[2]))-(length(X)*0.5*log(2*pi)))
	else
		logl = sum(logpdf(ERP,X))	
		if isinf(logl)
			logl = log(0)
		end
		return logl
	end
end

function ERP_CREATE(ERP, theta_c)
	if ERP == MvNormal #there's something wrong with julia's mvn
		return "NPR_MVN"
	else
		return ERP(theta_c[1],theta_c[2])
	end
end

function sample_new_randomness(params, name,ERP, theta_c, m, n)
	#sample new randomness
	ERP_OBJ = ERP_CREATE(ERP, theta_c)

	is_pregenerated_externally = false

	#first check if we have externally generated trace for initialization
	if typeof(params.TRACE_EXTERN) == typeof(Dict())
		if haskey(params.TRACE_EXTERN,name)
			#retrieve from externally initialized trace
			is_pregenerated_externally = true
			X = params.TRACE_EXTERN[name]["X"]
		end
	end

	if is_pregenerated_externally == false
		if ERP == MvNormal #there's something wrong with julia's mvn
			X = npr.multivariate_normal(theta_c[1],theta_c[2])
		else
			if m*n == 1
				X = rand(ERP_OBJ)
			else
				X = rand(ERP_OBJ, (m, n))[:]
			end
		end
	end


	logl = logscore_erp(ERP_OBJ, X, theta_c)

	params.CURRENT_TRACE["RC"][name]=Dict()
	params.CURRENT_TRACE["RC"][name]["ERP"]=ERP
	params.CURRENT_TRACE["RC"][name]["size"] = [m,n]
	params.CURRENT_TRACE["RC"][name]["logl"]=logl
	params.CURRENT_TRACE["RC"][name]["X"]=X
	params.CURRENT_TRACE["RC"][name]["theta_c"]=theta_c
	params.CURRENT_TRACE["ll"]+=logl; params.CURRENT_TRACE["ll_fresh"]+=logl
	return X, params
end


function DB_RandomManager(params, name, theta_c, ERP, m, n)
	X=NaN

	if (haskey(params.CURRENT_TRACE["RC"],name) == true) && (params.CURRENT_TRACE["RC"][name]["ERP"]==ERP)
		X = params.CURRENT_TRACE["RC"][name]["X"]
		if length(X) != m*n #case for block. If size changes of the LHS array, we need to resample with new dimensions so we don't get dimension mismatch error
			X, params=sample_new_randomness(params,name,ERP, theta_c, m, n)
		else
			if params.CURRENT_TRACE["RC"][name]["theta_c"] == theta_c
				params.CURRENT_TRACE["ll"]+= params.CURRENT_TRACE["RC"][name]["logl"]
			else
				#rescore ERP with new parameters
				ERP_OBJ = ERP_CREATE(ERP, theta_c)
				logl = logscore_erp(ERP_OBJ,X, theta_c) 
				params.CURRENT_TRACE["RC"][name]["logl"]=logl
				params.CURRENT_TRACE["ll"]+=logl
			end
		end
	else
		X, params=sample_new_randomness(params,name,ERP, theta_c, m, n)
		if GRADIENT_CALC == true
			params.CURRENT_TRACE["RC"][name]["ch_object"] = ch.array(X)
		end
	end
	params.CURRENT_TRACE["ACTIVE_K"][name]=1

	if GRADIENT_CALC == true
		if haskey(params.CURRENT_TRACE["RC"][name], "ch_object") == true
			#avoid creating a different ch_array. shouldn't matter functionally but creates memory leak
			if length(X) == 1
				set!(params.CURRENT_TRACE["RC"][name]["ch_object"],0,X[1])
			else
				for ii=1:length(X)
					#i-1 because python starts with 0 index
					set!(params.CURRENT_TRACE["RC"][name]["ch_object"],ii-1,X[ii])
				end
			end
		else
			params.CURRENT_TRACE["RC"][name]["ch_object"] = ch.array(X)
		end
		return params.CURRENT_TRACE["RC"][name]["ch_object"]
	else
		return X
	end
end

function StochasticObject(objects, instance)
	move_p = [0.9,0.05,0.05] #update/add/remove
	if length(objects) == 0
		max_oid = 0
		move = "add"
	else
		_keys=collect(keys(objects))
		max_oid = maximum(_keys)+1
		move = NaN
		chosen = find(rand(Multinomial(1,move_p)))[1]
		if chosen == 1
			move="update"
		elseif  chosen == 2
			move="add"
		else
			move="remove"
		end
	end
	if move == "update"
		return objects
	elseif move=="add"
		objects[max_oid]=instance
		params.CURRENT_TRACE["ll"]+= log(move_p[3]) - log(move_p[2])
		return objects
	elseif move == "remove"
		idx = rand(1:length(objects))
		chosen_key = _keys[idx]
		delete!(objects, chosen_key)
		params.CURRENT_TRACE["ll"]+= log(move_p[2]) - log(move_p[3])
		return objects
	end
end

function get_name(dist,FUNC,LINE,LOOP, MEM, BID)
	if isnan(MEM) == false
		name = string(dist,"_F", length(FUNC)>0?top(FUNC):0,"_L",length(LINE)>0?top(LINE):0,"_M",string(MEM))
	elseif BID != ""
		#name = string(dist,"_F", length(FUNC)>0?top(FUNC):0,"_L",length(LINE)>0?top(LINE):0,"_B",string(BID))		
		name = string(BID)		
	else
		name = string(dist,"_F", length(FUNC)>0?top(FUNC):0,"_P",length(LOOP)>0?top(LOOP):0,"_L",length(LINE)>0?top(LINE):0)
	end
	return name
end

function PyJCast(val)
	if typeof(val) == PyObject
		val = convert(PyAny,val["r"])
		if length(val) == 1
			val = val[1]
		end
	end
	return val
end

function Beta_DB(a,b,m,n,LINE,FUNC,LOOP,MEM, BID)
	a = PyJCast(a)
	b = PyJCast(b)
	name = get_name("Beta",FUNC,LINE,LOOP, MEM, BID)
	theta_c = {a,b}
	ERP = Beta
	ret = DB_RandomManager(params, name, theta_c, ERP, m, n)

	##### gradient #####
	if GRADIENT_CALC
		data_ch = params.CURRENT_TRACE["RC"][name]["ch_object"]	
		ch_lpdf = pycall(chumpy_lib["multiply"],PyAny,a-1,data_ch)
		tmp = pycall(chumpy_lib["subtract"],PyAny,1,data_ch)
		tmp2 = pycall(chumpy_lib["multiply"],PyAny,b-1,tmp)
		params.CURRENT_TRACE["RC"][name]["ch_lpdf"] = pycall(chumpy_lib["add"],PyAny,ch_lpdf,tmp2)
	end

	return ret
end

function Gamma_DB(a,b,m,n,LINE,FUNC,LOOP,MEM, BID)
	a = PyJCast(a)
	b = PyJCast(b)
	name = get_name("Gamma",FUNC,LINE,LOOP, MEM, BID)
	theta_c = {a,b}
	ERP = Gamma
	ret = DB_RandomManager(params, name, theta_c, ERP, m, n)

	###### gradient ######
	if GRADIENT_CALC
		k=a; theta=b;
		data_ch = params.CURRENT_TRACE["RC"][name]["ch_object"]	
		ch_lpdf = pycall(chumpy_lib["multiply"],PyAny,data_ch,k-1)
		tmp = pycall(chumpy_lib["divide"],PyAny, data_ch, 1.0/theta)
		ch_lpdf = pycall(chumpy_lib["subtract"],PyAny,ch_lpdf,tmp)
		params.CURRENT_TRACE["RC"][name]["ch_lpdf"] = pycall(chumpy_lib["subtract"],PyAny,ch_lpdf,k*theta)
	end

	return ret
end

function MvNormal_DB(a,b,m,n,LINE,FUNC,LOOP,MEM, BID)
	a = PyJCast(a)
	b = PyJCast(b)
	name = get_name("MvNormal",FUNC,LINE,LOOP, MEM, BID)
	theta_c = {a,b}
	ERP = MvNormal
	return DB_RandomManager(params, name, theta_c, ERP, m, n)
end

function Uniform_DB(a,b,m,n,LINE,FUNC,LOOP,MEM, BID)
	a = PyJCast(a)
	b = PyJCast(b)
	name = get_name("Uniform",FUNC,LINE,LOOP, MEM, BID)
	theta_c = {a,b}
	ERP = Uniform
	ret = DB_RandomManager(params, name, theta_c, ERP, m, n)
	return ret
end

function DiscreteUniform_DB(a,b,m,n,LINE,FUNC,LOOP,MEM, BID)
	a = PyJCast(a)
	b = PyJCast(b)
	name = get_name("DiscreteUniform",FUNC,LINE,LOOP, MEM, BID)
	theta_c = {a,b}
	ERP = DiscreteUniform
	return DB_RandomManager(params, name, theta_c, ERP, m, n)
end

function Multinomial_DB(a,b,m,n,LINE,FUNC,LOOP,MEM, BID)
	a = PyJCast(a)
	b = PyJCast(b)
	name = get_name("Multinomial",FUNC,LINE,LOOP, MEM, BID)
	theta_c = {a,b}
	ERP = Multinomial
	return DB_RandomManager(params, name, theta_c, ERP, m, n)
end

function Normal_DB(a,b,m,n,LINE,FUNC,LOOP,MEM, BID)
	a = PyJCast(a)
	b = PyJCast(b)
	name = get_name("Normal",FUNC,LINE,LOOP, MEM, BID)
	theta_c = {a,b}
	ERP = Normal
	ret = DB_RandomManager(params, name, theta_c, ERP, m, n)

	###### gradient ######
	if GRADIENT_CALC
		mu=a; sigma=b;
		data_ch = params.CURRENT_TRACE["RC"][name]["ch_object"]	
		ch_lpdf = pycall(chumpy_lib["subtract"],PyAny,data_ch,mu)
		ch_lpdf = pycall(chumpy_lib["multiply"],PyAny,ch_lpdf, ch_lpdf)
		ch_lpdf=pycall(chumpy_lib["multiply"],PyAny,ch_lpdf,-1.0/(2*sigma*sigma));
		params.CURRENT_TRACE["RC"][name]["ch_lpdf"]=pycall(chumpy_lib["subtract"],PyAny,ch_lpdf,log(sqrt(2*pi*sigma*sigma)));
	end
	return ret
end



