# kernel-update

## To update kernel on AWS systems plz do the below steps.

Prereq: User must have sudo nopassword access to run script from sudo without asking for password.

1. Clone repo
  ' got clone git@github.com:manoj-patch/kernel-update.git '
2. Update the inventory.txt with the server ip on which you want to do the kernel update
  ' cd kernel-update '
  ' vi unventory.txt '
3. Update the user and User-Pass in script[aws-kernel-update.sh]
  ' vi aws-kernel-update.sh '
4. run aws-kernel-update.sh
  ' ./aws-kernel-update.sh '
