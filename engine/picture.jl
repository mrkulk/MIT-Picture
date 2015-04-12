
# module Picture

if isdefined(:struct) == false
type struct
	PROGRAM
	TRACE_EXTERN
	TRACE
	NEW_TRACE
	CURRENT_TRACE
	LOOP_LIST
	TAST
	OBSERVATIONS
	USER_DEFINED
	TAPE
end
end

global params = struct(NaN,NaN,Dict(), Dict(),Dict(),Dict(), NaN,NaN, Dict(), Dict())

global GRADIENT_CALC = false


using Distributions
using Debug
using DataStructures

using PyCall
@pyimport numpy as np
@pyimport matplotlib.pyplot as plt
@pyimport opendr.util_tests as util_tests
@pyimport chumpy as ch
@pyimport opendr.simple as odr
@pyimport numpy.random as npr
@pyimport math as pmath
@pyimport scipy.misc as scpy
@pyimport gc as garbage
chumpy_lib = pyimport(:chumpy)


garbage.disable()

include("erps.jl")
include("codetransform.jl")
include("proposals.jl")
include("hmc.jl")
include("optimize.jl")
include("mcmcML.jl")
include("elliptical.jl")
include("torch_interface.jl")
include("gibbs_kernel.jl")
# @debug begin 

#################### GLOBAL STRUCTURES ###################
# global TRACE = Dict()
# global NEW_TRACE = Dict()
# global CURRENT_TRACE = Dict()

# global LOOP_LIST = Dict()

# AST = NaN
# TAST = NaN


#################### HELPER FUNCTIONS ####################
#Appending to arrays
myappend{T}(v::Vector{T}, x::T) = [v..., x]


function check_if_random_choice(expression)
	str_exp = string(expression)
	if search(str_exp,"observe") != 0:-1
		return false
	end
	
	if search(str_exp, "block") != 0:-1
		return true
	end

	if search(str_exp, "memoize") != 0:-1
		return true
	end

	# try check_block = string(expression.args[2].args[1])
	# 	if check_block == "block"
	# 		return true
	# 	end
	# catch
	# 	ret = false
	# end

	ret = false
	try	input_erp = string(expression.args[2].args[1]) #string(expression.args[2].args[2].args[2].args[1])
		ERPS = ["DiscreteUniform", "Bernoulli","Beta","Poisson", "Uniform","Normal","Multinomial", "Gamma", "MvNormal"]
		
		for i=1:length(ERPS)
			#ret = ret | (match(Regex(ERPS[i]),expression) != Nothing())
			ret = ret | (ERPS[i] == input_erp)
			if ret == true
				return ret
			end
		end
	catch
		ret = false
	end

	return ret
end


function is_theta_equal(theta_c, theta_d) #theta_c can have symbols
	equal = false

	for ii=1:length(theta_c)
		if typeof(theta_c[ii]) == Symbol
			theta_c[ii] = eval(theta_c[ii])
		end
		equal += (theta_c[ii] == theta_d[ii])
	end
	return equal
end

function trace_update(TAST)

	params.CURRENT_TRACE["ll"] = 0; params.CURRENT_TRACE["ll_fresh"] = 0; params.CURRENT_TRACE["ll_stale"] = 0;
	params.CURRENT_TRACE["ACTIVE_K"] = Dict()

	params.CURRENT_TRACE["PROGRAM_OUTPUT"] = eval(TAST[1].args[3])

	all_choices = unique(append!(collect(keys(params.CURRENT_TRACE["RC"])),collect(keys(params.CURRENT_TRACE["ACTIVE_K"]))))
	for name in all_choices
		if haskey(params.CURRENT_TRACE["ACTIVE_K"], name) == false #inactive
			ERP = params.CURRENT_TRACE["RC"][name]["ERP"]
			theta_d = params.CURRENT_TRACE["RC"][name]["theta_c"]
			VAL = params.CURRENT_TRACE["RC"][name]["X"]
			params.CURRENT_TRACE["ll_stale"]+=logscore_erp(ERP_CREATE(ERP,theta_d),VAL, theta_d)
			delete!(params.CURRENT_TRACE,name)
		end
	end

	if params.CURRENT_TRACE["PROGRAM_OUTPUT"] == "OVERFLOW_ERROR"
		params.CURRENT_TRACE["ll"]=-1e200
	end
end

function load_program(PROGRAM)
	params.PROGRAM = PROGRAM
end

function load_observations(OBSERVATIONS)
	params.OBSERVATIONS = OBSERVATIONS
end

function initialize_trace_extern(funcFtr,args)
	params.TRACE_EXTERN = funcFtr(args)
end

function init()
	AST=code_lowered(params.PROGRAM,())
	#AST=code_lowered(PROGRAM,(Dict{Any,Any},))
	params.TAST = transform_code(AST)

	params.TRACE["RC"]=Dict()
	params.TRACE["observe"]=Dict()

	params.CURRENT_TRACE = deepcopy(params.TRACE)
	trace_update(params.TAST)
	params.TRACE = deepcopy(params.CURRENT_TRACE)
end


function observe_iid(trc,tag,input, output)
	trc.OBSERVATIONS = {"input"=>input, "output"=>output}
end


function trace(PROGRAM, args)
	params.OBSERVATIONS = args
	params.PROGRAM = PROGRAM
	AST=code_lowered(params.PROGRAM,())
	#AST=code_lowered(PROGRAM,(Dict{Any,Any},))
	params.TAST = transform_code(AST)

	params.TRACE["RC"]=Dict()
	params.TRACE["observe"]=Dict()

	params.CURRENT_TRACE = deepcopy(params.TRACE)
	trace_update(params.TAST)
	params.TRACE = deepcopy(params.CURRENT_TRACE)
	return params
end


function infer( debug_callback="", iterations = 100, group_name="", inference="MH_SingleSite", args="",mode="")
	println("Starting Inference [Scheme=",inference,"]")
	ll = params.TRACE["ll"];
	for iters=1:iterations
		if iters%50 == 0
			println("Iter#: ",iters)
		end
		rv_choices = collect(keys(params.TRACE["RC"]))
		if group_name == ""
			#select random f_k via its name
			idx=rand(1:length(params.TRACE["RC"]))
			chosen_rv = [rv_choices[idx]]
		else
			if group_name == "CYCLE" #reserved name for cycling through all variables
				indx = iters%length(rv_choices)
				indx = indx + 1
				chosen_rv = [rv_choices[indx]]
			else
				chosen_rv = [group_name]
			end
		end
		########## Metropolis Hastings ##########
		# println("CHOSEN:", chosen_rv)
		if inference == "MH" || inference == "MH_SingleSite"
			if typeof(chosen_rv) == Array{ASCIIString,1}
				chosen_rv = chosen_rv[1]
				new_X,new_logl, F, R = sample_from_proposal(params.TRACE,chosen_rv,inference)

				params.NEW_TRACE = deepcopy(params.TRACE)
				params.NEW_TRACE["RC"][chosen_rv]["X"]=new_X	
				params.NEW_TRACE["RC"][chosen_rv]["logl"]=new_logl
			else
				#block proposal
				params.NEW_TRACE = deepcopy(params.TRACE)
				for ii=1:length(chosen_rv)
					crv = chosen_rv[ii]
					new_X,new_logl, F, R = sample_from_proposal(params.TRACE,crv,inference)
					params.NEW_TRACE["RC"][crv]["X"]=new_X
					params.NEW_TRACE["RC"][crv]["logl"]=new_logl
				end
			end

			params.CURRENT_TRACE = deepcopy(params.NEW_TRACE)
			# println("AFTER CHOBJ:", params.CURRENT_TRACE["RC"]["G1"]["ch_object"])		
			trace_update(params.TAST)
			params.NEW_TRACE = deepcopy(params.CURRENT_TRACE)
			new_ll = params.NEW_TRACE["ll"]; ll_fresh = params.NEW_TRACE["ll_fresh"]; ll_stale = params.NEW_TRACE["ll_stale"]

			#acceptance ratio
			if new_ll == -1e200
				ACC = -1e200
			else
				ACC = new_ll - ll + R - F + log(length(params.TRACE["RC"])) - log(length(params.NEW_TRACE["RC"])) + ll_stale - ll_fresh
			end

			if mode == "HALLUCINATE"
				ACC = 1e100
			end

			if log(rand()) < ACC #accept
				params.TRACE = deepcopy(params.NEW_TRACE)
				ll = new_ll
				debug_callback(params.TRACE)
			else# Rejected
				params.NEW_TRACE = Dict()
			end
		########## HMC ##########
		elseif inference == "HMC"
			params.TRACE = hmc_propose(chosen_rv, debug_callback)
		elseif inference == "Gibbs"
			params.TRACE = gibbs_propose(chosen_rv, debug_callback)
		elseif inference == "LBFGS"
			params.TRACE = lbfgs_propose(chosen_rv, debug_callback, args)
		elseif inference == "SGD"
			params.TRACE = SGD(group_name, debug_callback, iterations)
		elseif inference == "ELLIPTICAL"
			params.TRACE = ELLIPTICAL(chosen_rv, debug_callback)
		end
	end

end

# end #debug

# end #module Picture



