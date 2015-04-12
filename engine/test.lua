--test script
require('sys')
function testdraw()
	sys.tic()
	ret = torch.rand(4)
	print(sys.toc())
	return ret
end

samples = testdraw()

function get_samples(index)
	return samples[index]
end