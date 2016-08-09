// diffobj - Compare R Objects with a Diff
// Copyright (C) 2016  Brodie Gaslam
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// Go to <https://www.r-project.org/Licenses/GPL-3> for a copy of the license.

/*
 * Compute the desired text width based on the line width and the width of
 * all the non-text elements.  This is pretty fragile and would benfit from
 * a better underlying HTML structure
 */
function get_text_width(cont) {
  var banner = cont.getElementsByClassName("line.banner");
  if(banner.length != 1 && banner.length != 2) {
    throw new Error("Should only be one or two banner lines");
  }
  var bannerDel = banner.getElementsByClassName("delete");
  if(bannerDel != 1) {
    throw new Error("Should only be one delete banner.");
  }
  var gutt = bannerDel.getElementsByClassName("gutter");
  if(gutt != 2) {
    throw new Error("Should be two gutter elements");
  }
  var extra = 0;  // cumulative width of all the non-text stuff

  for(i = 0; i < 2; i++) {
  }
  
}
/*
 * Resizes diff by changing font-size using a hidden row of sample output as
 * a reference
 */
function resize_diff_out(scale) {
  var w = document.body.clientWidth;
  var meta = document.getElementById("diffobj_size_meta");
  var meta_cont = document.getElementById("diffobj_content_meta");
  var meta_banner = document.getElementById("diffobj_banner_meta");
  var content = document.getElementById("diffobj_content");

  if(meta == null || content == null)
    throw new Error("Unable to find meta and content; contact maintainer.");

  var row = meta_cont.getElementsByClassName("row");

  if(row.length != 1)
    throw new Error("Unexpected row struct in meta block; contact maintainer.");

  var lines = meta_cont.getElementsByClassName("line");

  if(lines.length != 1 && lines.length != 2)
    throw new Error("Unexpected lines in meta block; contact maintainer.");

  meta.style.display = "block";

  var t = 0;
  var pad = 1;  // looks like scrollWidth returns floats truncated to ints

  for(i = 0; i < lines.length; i++) t = t + lines[i].scrollWidth + pad;

  meta.style.display = "none";
  content.style.width = t + "px";  // prevent wrapping outside of native width

  var scale_size = w / t;

  if(scale_size < 1) {
    content.style.width = t + "px";
    if(scale) {
      content.style.transform = "scale(" + scale_size + ")";
      content.style.transformOrigin = "top left";
      content.style.webkitTransform = "scale(" + scale_size + ")";
      content.style.webkitTransformOrigin = "top left";
      content.style.msTransform = "scale(" + scale_size + ")";
      content.style.msTransformOrigin = "top left";
    }
  } else {
    content.style.width = "auto";
    content.style.transform = "none";
    content.style.webkitTransform = "none";
    content.style.msTransform = "none";
  }
};
function resize_diff_out_scale() {resize_diff_out(true);}
function resize_diff_out_no_scale() {resize_diff_out(false);}

