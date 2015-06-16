module dsutils.brightness;

import std.stdio;
import std.math;
import std.range;
import std.file;
import std.conv;
import std.typecons;
import std.datetime;
import std.array;
import std.traits;
import std.string;
import std.algorithm;
import std.uni;
import core.thread;

/**
 * brightness
 */

alias Bright = Tuple!(int, "max", int, "actual");

/**
 *Get all the brightness
 * Params: folder in /sys/class/backlight/ where dsutils should look
 * Returns: the raw brightness
 */
Bright brightness(string folder){
	Bright bri;
	string path = "/sys/class/backlight/" ~ folder;
	File bMax = File(path ~ "/max_brightness", "r");
	string lineMax = bMax.readln();
	bri.max = to!int(strip(lineMax));

	File bActual = File(path ~ "/brightness", "r");
	string lineActual = bActual.readln();
	bri.actual = to!int(strip(lineActual));
	return bri;
}

/**
 * Convert a value from /sys/class/backlight/ in a percentage
 * of the brightness
 * Params:
 * 		bri = a Bright tuple
 * 		value = a value to convert
 * Returns: a percentage
 */
int brightnessToPercent(Bright bri, int value){
	assert(bri.max >= 0);
	assert(bri.actual >= 0);
	return value*100 / bri.max;
}