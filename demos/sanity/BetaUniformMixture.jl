
include("../../engine/picture.jl")

using Debug

################### PROBABILISTIC CODE ###############
global OBSERVATIONS = [2.4,23.1,13.43,0.00067880843013236,0.03340098415969128,7.401553364861542e-9]
function PROGRAM()
	LINE=Stack(Int);FUNC=Stack(Int);LOOP=Stack(Int);MEM=NaN; BID=NaN;
	m=DiscreteUniform(2,6, 1,1)
	X=zeros(2*m)

	X[1:m] = block("G1",Uniform(20,30, 1, m))

	# for i=1:m
	# 	X[i]=Uniform(0,0.4, 1, 1)
	# end

	for i=m+1:2*m
		X[i]=Beta(0.1,1, 1,1)
	end

	if length(OBSERVATIONS) != length(X)
		println("OVERFLOW_ERROR")
		return "OVERFLOW_ERROR"
	end

	#observations
	for k=1:length(OBSERVATIONS)
		observe(k, Normal(X[k],0.0005),OBSERVATIONS[k])
	end

	return m,X
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
	for jj=1:length(TRACE["PROGRAM_OUTPUT"][2])
		@printf("%2f,", TRACE["PROGRAM_OUTPUT"][2][jj])
	end
	println("\nLOGL:", TRACE["ll"])
	println()
end


trc = trace(PROGRAM,[])
infer(debug_callback,1000,"CYCLE")

# infer(debug_callback,1000,"G1")
# infer(debug_callback,1000)
