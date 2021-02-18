<!-- Provide a general summary of the issue in the Title above -->
<!-- Note: these are comments that don't show up in the actual issue, no need to delete them as you fill out the template -->

<!-- IMPORTANT Complete the entire template please, the info gathered here is usually needed to debug issues anyway so it saves time in the long run. Incomplete/stock template issues may be closed -->

<!-- pick ONE: Bug, 
               Feature Request, 
               Run Issue (running Pi-hole container failing), 
               Build Issue (Building image failing) 
Enter in line below: -->
This is a: **FILL ME IN**  


## Details
<!-- Provide a more detailed introduction to the issue or feature, try not to duplicate info from lower sections by reviewing the entire template first -->

## Related Issues
- [ ] I have searched this repository/Pi-hole forums for existing issues and pull requests that look similar 
<!-- Add links below! -->

<!------- FEATURE REQUESTS CAN STOP FILLING IN TEMPLATE HERE -------->
<!------- ISSUES SHOULD FILL OUT REMAINDER OF TEMPLATE -------->

## How to reproduce the issue 

1. Environment data
  * Operating System: **ENTER HERE** <!-- Debian, Ubuntu, Rasbian, etc -->
  * Hardware: <!-- PC, RasPi B/2B/3B/4B, Mac, Synology, QNAP, etc -->
  * Kernel Architecture: <!-- x86/amd64, ArmV7, ArmV8 32bit, ArmV8 64bit, etc -->
  * Docker Install Info and version: 
    - Software source: <!-- official docker-ce, OS provided package, Hypriot -->
    - Supplimentary Software: <!-- synology, portainer, etc -->
  * Hardware architecture: <!-- ARMv7, x86 -->

2. docker-compose.yml contents, docker run shell command, or paste a screenshot of any UI based configuration of containers here
3. any additional info to help reproduce


## These common fixes didn't work for my issue
<!-- IMPORTANT! Help me help you! Ordered with most common fixes first. -->
- [ ] I have tried removing/destroying my container, and re-creating a new container
- [ ] I have tried fresh volume data by backing up and moving/removing the old volume data
- [ ] I have tried running the stock `docker run` example(s) in the readme (removing any customizations I added)
- [ ] I have tried a newer or older version of Docker Pi-hole (depending what version the issue started in for me)
- [ ] I have tried running without my volume data mounts to eliminate volumes as the cause

If the above debugging / fixes revealed any new information note it here.
Add any other debugging steps you've taken or theories on root cause that may help.
