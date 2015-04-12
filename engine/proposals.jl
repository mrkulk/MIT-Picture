
function sample_from_proposal(DB,name,inference)

	random_var = deepcopy(DB["RC"][name])
	dimensionality = length(random_var["X"])

	theta_d = random_var["theta_c"]
	erp = random_var["ERP"]
	dist = ERP_CREATE(erp, theta_d)
	size = random_var["size"]
	if erp == MvNormal
		val = npr.multivariate_normal(theta_d[1],theta_d[2])
		F=0
		R=0
	else
		if size[1]*size[2] == 1
			val = rand(dist)
		else
			if inference == "MH_SingleSite"
				sample = rand(dist)
				sampled_indx = rand(DiscreteUniform(1,dimensionality))
				val = random_var["X"]
				val[sampled_indx] = sample
			elseif inference == "MH"
				val = rand(dist,(size[1],size[2]))
			else
				println("[ERROR] Specify valid inference scheme in sample_from_proposal()")
				return
			end
		end
		F = 0#logpdf(dist, val)
		R = 0#logpdf(dist, DB["RC"][name]["X"])
	end
	return val, logscore_erp(dist, val, theta_d), F, R
end




