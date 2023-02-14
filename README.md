# disk_archiver
a shellscript frontend to several tools for archiving old optical media

You'll need `bash`, `readom`, `ddrescue`, `xz`, etc.

run `disk_archiver.sh` without arguments to get help info, but usage:

`$./disk_archiver /dev/srX archive title with spaces`

... will create `archive_title_with_spaces.iso` and upon success, `archive_title_with_spaces.tar.xz`.
