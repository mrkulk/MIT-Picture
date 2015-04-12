using Debug
using Distributions

function get_bounds(names)
	bounds = 0

	for name in names
		tmp = 0
		erp = params.CURRENT_TRACE["RC"][name]["ERP"]
		theta = params.CURRENT_TRACE["RC"][name]["theta_c"]
		dim = length(params.CURRENT_TRACE["RC"][name]["X"])

		if erp == Uniform
			tmp = (theta[1], theta[2])
		elseif erp == Beta
			tmp = (0, 1)
		elseif erp == Normal || erp == Gamma 
			tmp = (-100, 100) #something wrong with ch.minimize. Should be None. Check later
		end
		for ii=1:dim
			if bounds == 0
				bounds = [tmp]
			else
				bounds = append!(bounds,[tmp])
			end
		end
	end

	return bounds
end


function lbfgs_propose(names, debug_callback, args)
	ll = params.TRACE["ll"]
	params.CURRENT_TRACE = deepcopy(params.TRACE)
	# trace_update(params.TAST)
	# variables_to_opt = 0
	# for name in names
	# 	if variables_to_opt == 0
	# 		variables_to_opt = params.CURRENT_TRACE["RC"][name]["ch_object"]
	# 		variables_to_opt = [variables_to_opt]
	# 	else
	# 		@bp
	# 		variables_to_opt = append!(variables_to_opt, params.CURRENT_TRACE["RC"][name]["ch_object"])
	# 	end
	# end
	variables_to_opt = [params.CURRENT_TRACE["RC"][name]["ch_object"] for name in names] 

	difference = pycall(chumpy_lib["subtract"],PyAny,  params.USER_DEFINED["ren"] , params.OBSERVATIONS["IMAGE"])
	gpr = odr.gaussian_pyramid(difference, n_levels=6, as_list=true)#[-3:]
	gpr = gpr[args["res"][1]:args["res"][2]]
	E = 0
	for i = 1:length(gpr)
		if i == 1
			E = pycall(chumpy_lib["ravel"],PyAny, gpr[i])
		else
			tmp = pycall(chumpy_lib["ravel"],PyAny, gpr[i])
			E =ch.concatenate((E, tmp))
		end
	end

	bounds = get_bounds(names)

	# bounds=[(-4,4),(-4,4),(-4,4),(-10,10),(-10,10),(-10,10),(-10,10),(-10,10),(-10,10),(-10,10),(-10,10),(-10,10)]

	# println("BEFORE:", params.CURRENT_TRACE["RC"]["G1"]["ch_object"])
	ch.minimize(fun=E,x0=variables_to_opt)#method="L-BFGS-B",bounds=bounds)
	# println("AFTER:", params.CURRENT_TRACE["RC"]["G1"]["ch_object"])
	
	for name in names	
		params.CURRENT_TRACE["RC"][name]["X"] = convert(PyAny,params.CURRENT_TRACE["RC"][name]["ch_object"]["r"])
		#add new logl
		theta_d = params.CURRENT_TRACE["RC"][name]["theta_c"]
		erp = params.CURRENT_TRACE["RC"][name]["ERP"]
		dist = ERP_CREATE(erp, theta_d)
		params.CURRENT_TRACE["RC"][name]["logl"] = logscore_erp(dist, params.CURRENT_TRACE["RC"][name]["X"], theta_d)
	end

	trace_update(params.TAST)
	new_ll = params.CURRENT_TRACE["ll"]


	new_ll = params.CURRENT_TRACE["ll"]; ll_fresh = params.CURRENT_TRACE["ll_fresh"]; ll_stale = params.CURRENT_TRACE["ll_stale"]
	ACC = new_ll - ll + log(length(params.TRACE["RC"])) - log(length(params.CURRENT_TRACE["RC"])) + ll_stale - ll_fresh
	
	# println("LBFGS: old_ll:", ll, " new_ll:", new_ll)
	if log(rand()) < ACC #accept
		println("ACCEPT")
		params.TRACE = deepcopy(params.CURRENT_TRACE)
		debug_callback(params.TRACE)
	else
		println("REJECT")
	end

	return params.TRACE
end




