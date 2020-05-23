This program monitors the levels of certain
items within the ME network. If the quantity of
an item drops below a specified threshhold, the
computer will emit a redstone signal.

# Colors
white     1
orange    2
magenta   4
lightBlue 8
yellow    16
lime      32
pink      64
gray      128
lightGray 256
cyan      512
purple    1024
blue      2048
brown     4096
green     8192
red       16384
black     32768

Example of an entry within resources.config:
# ID,DMG,lowThreshhold,COLOR,SIDE
minecraft:stone,0,100,2048,front
