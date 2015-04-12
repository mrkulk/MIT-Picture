

include("../../engine/picture.jl")
global OBSERVATIONS = [-0.44807272117069014,10.456668142334193,8.011686050745572,-0.08233999332655699,8.578355846740143,10.728612655587856,5.197286833474093,5.113429320476434,8.615976298430253,5.081957337632471]
global OBS_CID = [1,2,2,1,2,2,3,3,2,3]
############# PROBABILISTIC CODE ###########
function PROGRAM()
	LINE=Stack(Int);FUNC=Stack(Int);LOOP=Stack(Int);var=NaN	
	
	mixing_coeff = [0.5,0.3,0.2]
	mu = [0, 10, 5]
	stds = [1,2,0.1]
	DIM = 10
	X=zeros(DIM)
	CID=zeros(Int,DIM)
	for k=1:DIM
		tmp = Multinomial(1,mixing_coeff,1,1) 
		cid = findin(tmp,1)[1]
		X[k] = Normal(mu[cid], stds[cid],1,1)
		CID[k]=cid
	end
	if length(OBSERVATIONS) != length(X)
		return "OVERFLOW_ERROR"
	end
	for k=1:length(DIM)
		observe(k,Normal(mu[CID[k]],stds[CID[k]]),OBSERVATIONS[k])
	end

	return X,CID
end

########### USER DIAGNOSTICS ##############
function debug_callback(TRACE)
	println("------------------ACCEPTED------------------------")
	print("OBS:")
	for jj=1:length(OBSERVATIONS)
		@printf("%2f,", OBSERVATIONS[jj])
	end
	println()
	print("INF:")
	for jj=1:length(TRACE["PROGRAM_OUTPUT"][1])
		@printf("%2f,", TRACE["PROGRAM_OUTPUT"][1][jj])
	end
	println()
end

trc = trace(PROGRAM,[])
infer(debug_callback,1000, "CYCLE")


