Add hooks to Read/Update/Edit to track which files are in use within the session (LRU cache?)

On a pretooluse/posttooluse call, check those files. If they've changed, print into the convo that they have been changed.

On pretooluse/read, update the hash of that file
On pretooluse/update or pretooluse/edit, if it has changed, reject the tool use.

Maybe also see which dirs are being read and or any thing in the project (that isn't git ignored?) and print whenever a new file is added (or changed?)
