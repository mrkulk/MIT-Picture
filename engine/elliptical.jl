# Reference:
# % Elliptical slice sampling
# % Iain Murray, Ryan Prescott Adams and David J.C. MacKay.
# % The Proceedings of the 13th International Conference on Artificial
# % Intelligence and Statistics (AISTATS), JMLR W&CP 9:541-548, 2010.

using Debug
using Distributions

function ELLIPTICAL(names, debug_callback)
	params.CURRENT_TRACE = deepcopy(params.TRACE)
	trace_update(params.TAST)
	cur_log_like = params.CURRENT_TRACE["ll"]
	xx = params.CURRENT_TRACE["RC"][names[1]]["X"]
	# print("---------\n")
	# print("PREV:", cur_log_like, "\n")
	angle_range = 0; #parameter: currently explores whole ellipse

	prior = chol(eye(length(xx))); 
	D = length(xx)
	nu = reshape(prior'*rand(Normal(0,1),(D, 1)), size(xx))

	hh = log(rand()) + cur_log_like;

	#Set up a bracket of angles and pick a first proposal.
	# "phi = (theta'-theta)" is a change in angle.
    phi = rand()*2*pi;
    phi_min = phi - 2*pi;
    phi_max = phi;

    ERP = params.CURRENT_TRACE["RC"][names[1]]["ERP"]
    theta_c = {0,1} #hack -- should be passed in
	ERP_OBJ = ERP_CREATE(ERP, theta_c)

	#Slice sampling loop
	while true
	    # Compute xx for proposed angle difference and check if it's on the slice
	    xx_prop = xx*cos(phi) + nu*sin(phi);

	    # cur_log_like = log_like_fn(xx_prop, varargin{:});
	    params.CURRENT_TRACE["RC"][names[1]]["X"] = xx_prop
		trace_update(params.TAST)	
		cur_log_like = params.CURRENT_TRACE["ll"]

	    if cur_log_like > hh
	    	#New point is on slice, ** EXIT LOOP **
	    	# print("cur:", cur_log_like, "	hh:", hh, "\n")
    		logl = logscore_erp(ERP_OBJ,params.CURRENT_TRACE["RC"][names[1]]["X"], theta_c) 
			params.CURRENT_TRACE["RC"][names[1]]["logl"] = logl
			
	        params.TRACE = deepcopy(params.CURRENT_TRACE)
	        debug_callback(params.CURRENT_TRACE)
	        return params.CURRENT_TRACE
	    end
	    print("<ELLIPTICAL SLICE> Shrinking Slice\n")
	    #Shrink slice to rejected point
	    if phi > 0
	        phi_max = phi;
	    elseif phi < 0
	        phi_min = phi;
	    else
	        print("\n<ELLIPTICAL SLICE> BUG DETECTED: Shrunk to current position and still not acceptable.\n")
	    end
	    #Propose new angle difference
	    phi = rand()*(phi_max - phi_min) + phi_min;
	end
end




