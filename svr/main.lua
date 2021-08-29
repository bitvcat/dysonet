local skynet = require "skynet"

skynet.start(function()
	skynet.error("Server start")

	local debug_port = skynet.getenv("debug_port")
    if debug_port then
		skynet.newservice("debug_console", debug_port)
	end

	local tcp_gate = skynet.uniqueservice("tcp")
    skynet.call(tcp_gate,"lua","open", {port=1234})
	--skynet.exit()
end)