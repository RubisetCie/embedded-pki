touch "$dest_dir/data/$database"
echo '01' >"$dest_dir/data/$serial"
echo '01' >"$dest_dir/data/$crlnumber"
chmod $verb 0664 "$dest_dir/data/$database" "$dest_dir/data/$serial" "$dest_dir/data/$crlnumber" >$fd
