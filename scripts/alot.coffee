# Description:
#   Share some fun everytime alot is said
#
# Dependencies:
#   None
#
# Configuration:
#   None
#
# Commands:
#   None
#
# Author:
#   ndaversa

module.exports = (robot) ->
  alots = [
    "http://4.bp.blogspot.com/_D_Z-D2tzi14/S8TRIo4br3I/AAAAAAAACv4/Zh7_GcMlRKo/s400/ALOT.png",
    "http://3.bp.blogspot.com/_D_Z-D2tzi14/S8TTPQCPA6I/AAAAAAAACwA/ZHZH-Bi8OmI/s400/ALOT2.png"
    "http://3.bp.blogspot.com/_D_Z-D2tzi14/S8TWUJ0APWI/AAAAAAAACwI/014KRxexoQ0/s320/ALOT3.png",
    "http://2.bp.blogspot.com/_D_Z-D2tzi14/S8Tdnn-NE0I/AAAAAAAACww/khYjZePN50Y/s400/ALOT4.png",
    "http://4.bp.blogspot.com/_D_Z-D2tzi14/S8TfVzrqKDI/AAAAAAAACw4/AaBFBmKK3SA/s320/ALOT5.png",
    "http://1.bp.blogspot.com/_D_Z-D2tzi14/S8TflwXvTgI/AAAAAAAACxI/qgd1wYcTWV8/s320/ALOT12.png",
    "http://2.bp.blogspot.com/_D_Z-D2tzi14/S8TiTtIFjpI/AAAAAAAACxQ/HXLdiZZ0goU/s320/ALOT14.png",
    "http://1.bp.blogspot.com/_D_Z-D2tzi14/S8TpGRlt9eI/AAAAAAAACxY/qDqk63PhqGs/s400/ALOT15.png"
  ]

  robot.hear /\balot\b/i, (msg) ->
    msg.send msg.random alots
