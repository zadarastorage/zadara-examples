# For centos versions bellow 8
if ! grep -q cgroup.memory=nokmem "/etc/default/grub"; then
	# Get the line we wanna edit
	GRUBCMDLINE=$(grep '^GRUB_CMDLINE_LINUX=\".*$' "/etc/default/grub")
	# Remove spaces and tabs at the end of the line
	GRUBCMDLINE=$(sed  's/[ \t]*$//' <<< $GRUBCMDLINE)
	# Replace the final '"' with the parameter following a '"'
	GRUBCMDLINE=$(sed  "s/\"$/ cgroup.memory=nokmem\"/" <<< $GRUBCMDLINE)
	sed  "s/^GRUB_CMDLINE_LINUX=\".*$/$GRUBCMDLINE/" -i /etc/default/grub
fi
# dirty one liner that does the same thing
#sudo sed -i "/.*cgroup.memory=nokmem.*/$(echo -e "\0041")s/^GRUB_CMDLINE_LINUX=\".*$/$(cat /etc/default/grub | grep  '^GRUB_CMDLINE_LINUX=\".*$' | sed -e 's/[ \t]*$//' | sed  "s/\"$/ cgroup.memory=nokmem\"/")/" /etc/default/grub