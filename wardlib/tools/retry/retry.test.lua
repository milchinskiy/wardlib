-- Tinytest suite for tools.retry

return function(tinytest)
	local t = tinytest.new({ name = "tools.retry" })

	local MODULE = "wardlib.tools.retry"
	local loaded_orig = package.loaded[MODULE]

	local function reload()
		package.loaded[MODULE] = nil
		return require(MODULE)
	end

	t:after_all(function() package.loaded[MODULE] = loaded_orig end)

	t:test("call retries until success", function()
		local retry = reload()
		local attempts = 0

		local v = retry.call(function()
			attempts = attempts + 1
			if attempts < 3 then error("try again") end
			return "ok"
		end, { tries = 5, delay = 0, backoff = 1.0 })

		t:eq(v, "ok")
		t:eq(attempts, 3)
	end)

	t:test("should_retry can stop retries early", function()
		local retry = reload()
		local attempts = 0
		local seen_msg

		local ok, err = pcall(function()
			retry.call(function()
				attempts = attempts + 1
				error("fatal")
			end, {
				tries = 10,
				delay = 0,
				backoff = 1.0,
				should_retry = function(msg)
					seen_msg = msg
					return msg ~= "fatal"
				end,
			})
		end)

		t:falsy(ok)
		t:eq(seen_msg, "fatal")
		t:match(tostring(err), "fatal$")
		t:eq(attempts, 1)
	end)

	t:test("pcall returns (ok, value_or_err)", function()
		local retry = reload()

		local ok1, v1 = retry.pcall(function() return 42 end, { tries = 3, delay = 0 })
		t:truthy(ok1)
		t:eq(v1, 42)

		local ok2, v2 = retry.pcall(function() error("boom") end, { tries = 1, delay = 0 })
		t:falsy(ok2)
		t:match(tostring(v2), "boom")
	end)

	return t
end
