/*****
 * psfile.h
 * Andy Hammerlindl 2002/06/10
 *
 * Encapsulates the writing of commands to a PostScript file.
 * Allows identification and removal of redundant commands.
 *****/

#ifndef PSFILE_H
#define PSFILE_H

#include <fstream>
#include <stack>
#include <iomanip>

#include "pair.h"
#include "path.h"
#include "bbox.h"
#include "pen.h"

namespace camp {

class psfile {
  string filename;
  bbox box;
  pair shift;
  pen lastpen;
  ostream *out;
  std::stack<pen> pens;

  void write(pair z) {
    *out << " " << z.getx()+shift.getx() 
	 << " " << z.gety()+shift.gety();
  }

  void writeUnshifted(pair z) {
    *out << " " << z.getx() << " " << z.gety();
  }

  void write(transform t) {
    *out << "[" << " " << t.getxx() << " " << t.getyx()
                << " " << t.getxy() << " " << t.getyy()
	        << " " << t.getx()  << " " << t.gety() << "]";
  }

public: 
  psfile(const string& filename, const bbox& box, const pair& shift);
  ~psfile();
  
  void prologue();

  void epilogue();

  void setpen(pen p) {
    if(p == lastpen) return;
    
    if(p.cmyk() && (!lastpen.cmyk() || 
		    (p.cyan() != lastpen.cyan() || 
		     p.magenta() != lastpen.magenta() || 
		     p.yellow() != lastpen.yellow() ||
		     p.black() != lastpen.black()))) {
      *out << p.cyan() << " " << p.magenta() << " " << p.yellow() << " " 
	   << p.black() << " setcmykcolor" << newl;
    }
    
    if(p.rgb() && (!lastpen.rgb() || 
		   (p.red() != lastpen.red() || 
		    p.green() != lastpen.green() || 
		    p.blue() != lastpen.blue()))) {
      *out << p.red() << " " << p.green() << " " << p.blue()
	   << " setrgbcolor" << newl;
    }
    
    if(p.mono() && (!lastpen.mono() || p.gray() != lastpen.gray())) {
      *out << p.gray() << " setgray" << newl;
    }
    
    if(p.width() != lastpen.width()) {
      *out << " 0 " << p.width() << 
	" dtransform truncate idtransform setlinewidth pop" << newl;
    }
    
    if(p.stroke() != lastpen.stroke()) {
      *out << "[" << p.stroke() << "] 0 setdash" << newl;
    }
    
    lastpen=p;
  }

  void write(path p) {
    int n = p.size();
    assert(n != 0);

    newpath();

    if (n == 1) {
      moveto(p.point(0));
      rlineto(pair(0,0));
      stroke();
    }

    // Draw points
    moveto(p.point(0));
    for (int i = 1; i < n; i++) {
      if(p.straight(i-1)) lineto(p.point(i));
      else curveto(p.postcontrol(i-1), p.precontrol(i), p.point(i));
    }

    if (p.cyclic()) {
      if(p.straight(n-1)) lineto(p.point(0));
      else curveto(p.postcontrol(n-1), p.precontrol(0), p.point(0));
      closepath();
    }    
  }

  
  void newpath() {
      *out << "newpath";
  }

  void moveto(pair z) {
      write(z);
      *out << " moveto" << newl;
  }

  void lineto(pair z) {
      write(z);
      *out << " lineto" << newl;
  }

  void curveto(pair zp, pair zm, pair z1) {
      write(zp); write(zm); write(z1);
      *out << " curveto" << newl;
  }

  void closepath() {
      *out << " closepath" << newl;
  }

  void rlineto(pair z) {
      writeUnshifted(z);
      *out << " rlineto" << newl;
  }

  void stroke() {
    *out << " stroke" << newl;
  }
  
  void fill() {
    *out << " fill" << newl;
  }
  
  void clip() {
    *out << " clip" << newl;
  }
  
  void gsave() {
    *out << " gsave" << newl;
    pens.push(lastpen);
  }
  
  void grestore() {
    lastpen = pens.top();
    pens.pop();
    *out << " grestore" << newl;
  }

  void translate(pair z) {
    writeUnshifted(z);
    *out << " translate" << newl;
  }

  // Multiply on a transform to the transformation matrix.
  void concat(transform t) {
    write(t);
    *out << " concat" << newl;
  }
  
  void verbatim(const std::string& s) {
    *out << s << newl;
  }

};

} //namespace camp

#endif
