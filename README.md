# kernel-update

## To update kernel on AWS systems plz do the below steps.

Prereq: User must have sudo nopassword access to run script from sudo without asking for password.

1. Clone repo
2. Update the inventory.txt with the server ip on which you want to do the kernel update
3. Update the user and User-Pass in script[aws-kernel-update.sh]
4. run aws-kernel-update.sh
