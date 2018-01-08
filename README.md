# asana.el  
  
### Interact with an Asana-project comfortably within Emacs  
  
Makes an Asana-project available within Emacs. It uses `helm` to  
quickly filter tasks and once you've found the one your looking  
for, you can grab it (assign it to yourself); comment it or change  
it's current status. Additionally, you can commit your work using  
the task in it's entirety as the commit-message.  
  
For this package to work properly, you'll need to make your  
personal asana-token available. You do that, by adding it to the  
environment-variable `ASANA_TOKEN`. Then I would recommend making a  
`.dir-locals.el` in the root of your project where you set a  
project-id. Ex. `(setq asana-project-id "000000000000001")`  
That should be all there is to it. You can now issue asana-tasklist  
at will.  
  
> Author: Henrik Kjerringvåg <hekj@bdo.no>  
> License: GNU General Public License v.30  
> Version: 0.0.1  
