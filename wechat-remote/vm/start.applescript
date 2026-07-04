use framework "Foundation"

property launcherScript : "start.sh"
property logPath : "/tmp/orbstack-wechat-launcher.log"

on run
	set vmPath to my resolveVmPath()
	set shellCommand to "export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH; cd " & my q(vmPath) & " && exec ./" & launcherScript & " >> " & my q(logPath) & " 2>&1"
	
	set task to current application's NSTask's alloc()'s init()
	task's setLaunchPath:"/bin/zsh"
	task's setArguments:{"-lc", shellCommand}
	task's |launch|()
	task's waitUntilExit()
	
	set exitCode to task's terminationStatus()
	if exitCode is not 0 then
		error "OrbStack WeChat exited with status " & exitCode & ". See " & logPath
	end if
end run

on resolveVmPath()
	set bundlePath to ((current application's NSBundle's mainBundle())'s bundlePath()) as text
	if bundlePath ends with ".app" then
		set appURL to current application's NSURL's fileURLWithPath:bundlePath
		set appParentURL to appURL's URLByDeletingLastPathComponent()
		set vmURL to appParentURL's URLByDeletingLastPathComponent()
		return (vmURL's |path|()) as text
	end if
	
	set sourcePath to (POSIX path of (path to me))
	set sourceURL to current application's NSURL's fileURLWithPath:sourcePath
	set vmURL to sourceURL's URLByDeletingLastPathComponent()
	return (vmURL's |path|()) as text
end resolveVmPath

on q(valueText)
	set s to valueText as text
	set oldDelimiters to AppleScript's text item delimiters
	set AppleScript's text item delimiters to "'"
	set parts to text items of s
	set AppleScript's text item delimiters to "'\\''"
	set escaped to parts as text
	set AppleScript's text item delimiters to oldDelimiters
	return "'" & escaped & "'"
end q
