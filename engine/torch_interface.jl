#Torch interface from Julia

module TORCH
using JSON
using ZMQ

ctx=Context(1)
s1=Socket(ctx, REQ)

export load_torch_script
export call
export close

#PORT = 7000
global PORT = -1

function setport(PORTN)
	global PORT
	PORT = PORTN
end

function load_torch_script(script_name)
	global PORT
	println("Port:", PORT)
	ZMQ.connect(s1, string("tcp://localhost:", PORT))
	CMD = string("{\"cmd\":\"load\", \"name\":\"", script_name ,"\"}")
	ZMQ.send(s1,Message(CMD))
	msg = ZMQ.recv(s1)
	out=convert(IOStream, msg)
	seek(out,0)
	msg = takebuf_string(out)
	msg = JSON.parse(msg)
	return msg
end

function call(func, args)
	global PORT
	# ZMQ.connect(s1, string("tcp://localhost:", PORT))
	CMD = string("{\"cmd\":\"call\",", "\"msg\":{" ,"\"func\":\"", func , "\",\"args\":\"", args, "\"}}")
	ZMQ.send(s1,Message(CMD))
	msg = ZMQ.recv(s1)
	out=convert(IOStream, msg)
	seek(out,0)
	msg = takebuf_string(out)
	msg = JSON.parse(msg)
	return msg
end

function close()
	ZMQ.close(sock)
	ZMQ.close(ctx)
end

end