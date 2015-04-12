

using Debug
using Distributions
using NumericExtensions

function gibbs_propose(names, debug_callback)

	params.CURRENT_TRACE = deepcopy(params.TRACE)

	xx = params.CURRENT_TRACE["RC"][names[1]]["X"]
	range = params.CURRENT_TRACE["RC"][names[1]]["theta_c"]

	logl_list = zeros(range[2]-range[1]+1)	
	val_list = {};ind=1
	for val = range[1]:range[2] #enumerate
		params.CURRENT_TRACE["RC"][names[1]]["X"] = val
		trace_update(params.TAST)	
		cur_log_like = params.CURRENT_TRACE["ll"]
		logl_list[ind] = cur_log_like
		ind+=1
		val_list = [val_list, val]
	end

	#sample from multinomial and choose
	logl_list = logl_list - logsumexp(logl_list)
	logl_list = exp(logl_list)
	pvector = rand(Multinomial(1,logl_list),1) 
	chosen_idx = findin(pvector,1)[1]

	#update trace with chosen value
    params.CURRENT_TRACE["RC"][names[1]]["X"] = val_list[chosen_idx]
	trace_update(params.TAST)	
	params.TRACE = deepcopy(params.CURRENT_TRACE)
	debug_callback(params.CURRENT_TRACE)
	return params.CURRENT_TRACE
end




