using Debug
using Distributions


function setArray(v,newv)
	for i = 0:np.shape(v)[1]-1
		for j=0:np.shape(v)[2]-1
			if typeof(newv) == Array{Int64,2}
				set!(v,(i,j), newv[i+1,j+1])
			else
				set!(v,(i,j),int(get(newv,(i,j))))
			end
		end
	end
	return v
end

function gradient_update(param, cost, lrate)
	grad = pycall(cost["dr_wrt"],PyAny,param)
	grad = convert(PyAny,grad["A"])	
	grad = sum(grad,1)/size(grad,1)
	grad = reshape(grad, np.shape(param)[1], np.shape(param)[2])
	
	new_param = np.subtract(param, lrate*grad)

	for i = 0:np.shape(param)[1]-1
		for j=0:np.shape(param)[2]-1
			if np.shape(param)[2] == 1
				set!(param,i,new_param[i+1])
			else
				set!(param,(i,j), new_param[i+1,j+1])
			end
		end
	end

	return param	
end

function SGD(names, debug_callback, args)
	DATA = params.OBSERVATIONS["input"]
	pout = params.CURRENT_TRACE["PROGRAM_OUTPUT"]
	# W = pout["params"][1]
	# bias_h = pout["params"][2]
	# bias_v = pout["params"][3]

	v = pout["obs"]
	loss = pout["loss"]
	lrate = pout["lrate"]

	# grad = pycall(pout["cost"]["dr_wrt"],PyAny,pout["params"])
	# grad = sum(grad)/length(grad)
	# set!(pout["params"],(0,0),0.5)	

	num_batches = length(DATA)-1 #1 of them is test

	for i=1:args #args=iterations
		#choose random minibatch
		batch = rand(DiscreteUniform(1,num_batches),1)[1]

		v = setArray(v, np.array(DATA[string("training_batch_",batch)],"int"))

		#update params
		for j=1:length(pout["params"])
			pout["params"][j] = gradient_update(pout["params"][j], loss, lrate)
		end
		debug_callback(pout["params"][1],pout["params"][2],pout["params"][3])
	end
	exit()
end

function MCMC_ML(names, debug_callback, args)
	print("Not implemented in this version")
end




