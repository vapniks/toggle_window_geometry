#!/usr/bin/env zsh

setopt extendedglob
# Alter this to change the default window geometries to toggle between
typeset -a defaultgeoms=("100%x100%" "100%x50%")

usage() {
  less -FEXR <<'HELP'
Usage: toggle_window_geometry.zsh [xdotool search options] PATTERN -- X1,Y1:W1xH1 X2,Y2:W2xH2 ...

Toggle the geometry of a window between the list of geometries provided on the command line. 
Each geometry takes the form X,Y:WxH or X,Y or WxH, where X & Y define the location of the top left
corner of the window, and WxH defines the width & height. Missing values (e.g. for X,Y or WxH forms)
will be replaced with values matching the current state of the selected window. 
Each of X,Y,W & H may be either a pixel count or a screen percentage. 
Examples:  0,140:100%x80%,  0,140,  100%x80%, 1280x576

The current window geometry is compared with those provided on the command line, and the nearest 
match found. Then the window is resized to match the next geometry in the list, or if the nearest 
match was the last one in the list, then the first one is used.

If no geometries are provided on the command line then 100%x100% & 100%x50% are used, 
i.e. toggle between full size & half height windows.

Options coming before -- are passed to "xdotool search" to identify the window to resize. 
You must quote anchor chars (e.g. ^ & $) in the window PATTERN, e.g. '\^xterm\$'

Example: toggle_window_geometry.zsh --onlyvisible --class "\^xterm" -- 50%x50% 100%x50% 100%x100%
HELP
}

if [[ "${@[(I)-h|--help]}" -gt 0 ]]; then usage; exit; fi

local searchopts breakidx="${@[(I)--]}"
local -a geometries
if [[ $breakidx -gt 0 ]]; then
    searchopts="${@[1,((${@[(I)--]}-1))]}"
else
    usage
    exit
fi
geometries=("${@[((${@[(I)--]}+1)),${#@}]}")
if [[ ${#geometries} == 0 ]]; then
    set -A geometries ${defaultgeoms[@]}
fi

local winid currdims screendims
winid=$(eval "xdotool search --sync ${searchopts}")
if (($?>0)); then
    print "Unable to find window with: xdotool search ${searchopts}"
    exit
fi
currdims=("${(f)$(xdotool getwindowgeometry $winid)}")
screendims="$(xdotool getdisplaygeometry)"
local currx curry currwidth currheight screenwidth screenheight
currx="${${currdims[2]}//* (#b)([0-9]##),[0-9]##*/${match}}"
curry="${${currdims[2]}//* (#b)[0-9]##,([0-9]##)*/${match}}"
currwidth="${${currdims[3]}//* (#b)([0-9]##)x[0-9]##*/${match}}"
currheight="${${currdims[3]}//* (#b)[0-9]##x([0-9]##)*/${match}}"
screenwidth="${screendims// [0-9]##}"
screenheight="${screendims//[0-9]## }"

geomx() {
    if [[ ${1} == *,* ]]; then
	local dim="${1//(#b)([0-9%]##),[0-9%]##:*/${match}}"
	if [[ $dim == *%* ]]; then
	    print "$((${dim//\%}*screenwidth/100))"
	else
	    print "${dim}"
	fi
    else
	print "${currx}"
    fi
}

geomy() {
    if [[ ${1} == *,* ]]; then
	local dim="${1//[0-9%]##,(#b)([0-9%]##):*/${match}}"
	if [[ $dim == *%* ]]; then
	    print "$((${dim//\%}*screenheight/100))"
	else
	    print "${dim}"
	fi
    else
	print "${curry}"
    fi
}

geomwidth() {
    if [[ ${1} == *x* ]]; then
	local dim="${1//(*:|(#s))(#b)([0-9%]##)x[0-9%]##/${match}}"
	if [[ $dim == *%* ]]; then
	    print "$((${dim//\%}*screenwidth/100))"
	else
	    print "${dim}"
	fi
    else
	print "${currwidth}"
    fi
}

geomheight() {
    if [[ ${1} == *x* ]]; then    
	local dim="${1//(*:|(#s))(#b)[0-9%]##x([0-9%]##)/${match}}"    
	if [[ $dim == *%* ]]; then
	    print "$((${dim//\%}*screenheight/100))"
	else
	    print "${dim}"
	fi
    else
	print "${currheight}"
    fi
}

local i geom best dist mindist=$((2*(screenwidth**2+screenheight**2)))
foreach i ({1..${#geometries}}) {
    geom=${geometries[$i]}
    if [[ ${geom} == *([0-9%]##,[0-9%]##|[0-9%]##x[0-9%]##)* ]]; then
	dist=$((((currx-$(geomx ${geom}))**2+(curry-$(geomy ${geom}))**2+(currwidth-$(geomwidth ${geom}))**2+(currheight-$(geomheight ${geom}))**2)))
	if ((dist < mindist)); then
	    mindist=${dist}
	    best=${i}
	fi
    else
	print "Invalid geometry: ${geom}"
	exit
    fi
}

if ((best==${#geometries})); then
    best=0
fi
local newx newy newwidth newheight
newx=$(geomx ${geometries[((best+1))]})
newy=$(geomy ${geometries[((best+1))]})
newwidth=$(geomwidth ${geometries[((best+1))]})
newheight=$(geomheight ${geometries[((best+1))]})

xdotool windowmove --sync ${winid} ${newx} ${newy}
xdotool windowsize --sync ${winid} ${newwidth} ${newheight}

