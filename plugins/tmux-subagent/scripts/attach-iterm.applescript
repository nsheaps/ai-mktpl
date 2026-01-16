#!/usr/bin/osascript
-- attach-iterm.applescript
-- Opens a new iTerm2 tab and attaches it to a tmux session
--
-- Usage: osascript attach-iterm.applescript <session-name>
--
-- This script:
-- 1. Activates iTerm2 (or launches it if not running)
-- 2. Creates a new tab in the current window
-- 3. Attaches that tab to the specified tmux session
-- 4. Sets the tab title to the session name

on run argv
    set sessionName to item 1 of argv

    tell application "iTerm2"
        -- Activate iTerm (bring to front, launch if needed)
        activate

        -- Get the current window or create one
        if (count of windows) = 0 then
            create window with default profile
        end if

        tell current window
            -- Create a new tab
            create tab with default profile

            tell current session
                -- Set the session name as the tab title
                set name to "Claude: " & sessionName

                -- Attach to the tmux session
                write text "tmux attach -t " & quoted form of sessionName
            end tell
        end tell
    end tell

    return "Attached to tmux session: " & sessionName
end run
