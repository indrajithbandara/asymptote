public frame patterns;
public bool shipped=false;

real cap(real x, real m, real M, real bottom, real top)
{
  return x+top > M ? M-top : x+bottom < m ? m-bottom : x;
}

// Scales pair z, so that when drawn with pen p, it does not exceed box(lb,rt).
pair cap(pair z, pair lb, pair rt, pen p=currentpen)
{

  return (cap(z.x,lb.x,rt.x,min(p).x,max(p).x),
          cap(z.y,lb.y,rt.y,min(p).y,max(p).y));
}

real xtrans(transform t, real x)
{
  return (t*(x,0)).x;
}

real ytrans(transform t, real y)
{
  return (t*(0,y)).y;
}

real cap(transform t, real x, real m, real M, real bottom, real top,
	 real ct(transform,real))
{
  return x == infinity  ? M-top :
         x == -infinity ? m-bottom : cap(ct(t,x),m,M,bottom,top);
}

pair cap(transform t, pair z, pair lb, pair rt, pen p=currentpen)
{
  if (finite(z))
    return cap(t*z, lb, rt, p);
  else
    return (cap(t,z.x,lb.x,rt.x,min(p).x,max(p).x,xtrans),
            cap(t,z.y,lb.y,rt.y,min(p).y,max(p).y,ytrans));
}
  
// A function that draws an object to frame pic, given that the transform
// from user coordinates to true-size coordinates is t.
typedef void drawer(frame f, transform t);

// A generalization of drawer that includes the final frame's bounds.
typedef void drawerBound(frame f, transform t, transform T, pair lb, pair rt);

// A coordinate in "flex space." A linear combination of user and true-size
// coordinates.
  
struct coord {
  public real user,truesize;
  public bool finite=true;

  // Build a coord.
  static coord build(real user, real truesize) {
    coord c=new coord;
    c.user=user;
    c.truesize=truesize;
    return c;
  }

  // Deep copy of coordinate.  Users may add coords to the picture, but then
  // modify the struct. To prevent this from yielding unexpected results, deep
  // copying is used.
  coord copy() {
    return build(user, truesize);
  }
  
  void clip(real min, real max) {
    user=min(max(user,min),max);
  }
}

coord operator init() {return new coord;}
  
struct coords2 {
  coord[] x;
  coord[] y;
  void erase() {
    x=new coord[];
    y=new coord[];
  }
  // Only a shallow copy of the individual elements of x and y
  // is needed since, once entered, they are never modified.
  coords2 copy() {
    coords2 c=new coords2;
    c.x=copy(x);
    c.y=copy(y);
    return c;
  }
  void append(coords2 c) {
    x.append(c.x);
    y.append(c.y);
  }
  void push(pair user, pair truesize) {
    x.push(coord.build(user.x,truesize.x));
    y.push(coord.build(user.y,truesize.y));
  }
  void push(coord cx, coord cy) {
    x.push(cx);
    y.push(cy);
  }
  void push(transform t, coords2 c1, coords2 c2)
  {
    for(int i=0; i < c1.x.length; ++i) {
      coord cx=c1.x[i], cy=c2.y[i];
      pair tinf=shiftless(t)*((finite(cx.user) ? 0 : 1),
			      (finite(cy.user) ? 0 : 1));
      pair z=t*(cx.user,cy.user);
      pair w=(cx.truesize,cy.truesize);
      w=length(w)*unit(shiftless(t)*w);
      coord Cx,Cy;
      Cx.user=(tinf.x == 0 ? z.x : infinity);
      Cy.user=(tinf.y == 0 ? z.y : infinity);
      Cx.truesize=w.x;
      Cy.truesize=w.y;
      push(Cx,Cy);
    }
  }
  void xclip(real min, real max) {
    for(int i=0; i < x.length; ++i) 
      x[i].clip(min,max);
  }
  void yclip(real min, real max) {
    for(int i=0; i < y.length; ++i) 
      y[i].clip(min,max);
  }
}
  
coords2 operator init() {return new coords2;}

bool operator <= (coord a, coord b)
{
  return a.user <= b.user && a.truesize <= b.truesize;
}

bool operator >= (coord a, coord b)
{
  return a.user >= b.user && a.truesize >= b.truesize;
}

// Find the maximal elements of the input array, using the partial ordering
// given.
coord[] maxcoords(coord[] in, bool operator <= (coord,coord))
{
  // As operator <= is defined in the parameter list, it has a special
  // meaning in the body of the function.

  coord best;
  coord[] c;

  int n=in.length;
  
  // Find the first finite restriction.
  int first=0;
  for(first=0; first < n; ++first)
    if(finite(in[first].user)) break;
	
  if (first == n)
    return c;
  else {
    // Add the first coord without checking restrictions (as there are none).
    best=in[first];
    c.push(best);
  }

  static int NONE=-1;

  int dominator(coord x)
  {
    // This assumes it has already been checked against the best.
    for (int i=1; i < c.length; ++i)
      if (x <= c[i])
        return i;
    return NONE;
  }

  void promote(int i)
  {
    // Swap with the top
    coord x=c[i];
    c[i]=best;
    best=c[0]=x;
  }

  void addmaximal(coord x)
  {
    coord[] newc;

    // Check if it beats any others.
    for (int i=0; i < c.length; ++i) {
      coord y=c[i];
      if (!(y <= x))
        newc.push(y);
    }
    newc.push(x);
    c=newc;
    best=c[0];
  }

  void add(coord x)
  {
    if (x <= best || !finite(x.user))
      return;
    else {
      int i=dominator(x);
      if (i == NONE)
        addmaximal(x);
      else
        promote(i);
    }
  }

  for(int i=1; i < n; ++i)
    add(in[i]);

  return c;
}

typedef real scalefcn(real x);
					      
public struct scaleT {
  scalefcn T,Tinv;
  bool logarithmic;
  bool automin,automax;
  void init(scalefcn T, scalefcn Tinv, bool logarithmic=false,
	    bool automin=true, bool automax=true) {
    this.T=T;
    this.Tinv=Tinv;
    this.logarithmic=logarithmic;
    this.automin=automin;
    this.automax=automax;
  }
  scaleT copy() {
    scaleT dest=new scaleT;
    dest.init(T,Tinv,logarithmic,automin,automax);
    return dest;
  }
};

scaleT operator init()
{
  scaleT S=new scaleT;
  S.init(identity,identity);
  return S;
}
				  
public struct autoscaleT {
  public scaleT scale;
  public scaleT postscale;
  public real tickMin=-infinity, tickMax=infinity;
  public bool automin=true, automax=true;
  public bool automin() {return automin && scale.automin;}
  public bool automax() {return automax && scale.automax;}
  
  real T(real x) {return postscale.T(scale.T(x));}
  scalefcn T() {return scale.logarithmic ? postscale.T : T;}
  real Tinv(real x) {return scale.Tinv(postscale.Tinv(x));}
  
  autoscaleT copy() {
    autoscaleT dest=new autoscaleT;
    dest.scale=scale.copy();
    dest.postscale=postscale.copy();
    dest.tickMin=tickMin;
    dest.tickMax=tickMax;
    dest.automin=(bool) automin;
    dest.automax=(bool) automax;
    return dest;
  }
}

autoscaleT operator init() {return new autoscaleT;}
				  
public struct ScaleT {
  public bool set=false;
  public autoscaleT x;
  public autoscaleT y;
  public autoscaleT z;
  
  ScaleT copy() {
    ScaleT dest=new ScaleT;
    dest.set=set;
    dest.x=x.copy();
    dest.y=y.copy();
    dest.z=z.copy();
    return dest;
  }
};

ScaleT operator init() {return new ScaleT;}

struct Legend {
  public string label;
  public pen plabel;
  public pen p;
  public frame mark;
  public bool put;
  void init(string label, pen plabel=currentpen, pen p=nullpen,
	    frame mark=newframe, bool put=Above) {
    this.label=label;
    this.plabel=plabel;
    this.p=(p == nullpen) ? plabel : p;
    this.mark=mark;
    this.put=put;
  }
}

Legend operator init() {return new Legend;}

pair realmult(pair z, pair w) 
{
  return (z.x*w.x,z.y*w.y);
}

pair rectify(pair dir) 
{
  real scale=max(abs(dir.x),abs(dir.y));
  if(scale != 0) dir *= 0.5/scale;
  dir += (0.5,0.5);
  return dir;
}

pair point(frame f, pair dir)
{
  return min(f)+realmult(rectify(dir),max(f)-min(f));
}

real min(... real[] a) {return min(a);}
real max(... real[] a) {return max(a);}

// Returns a copy of frame f aligned in the direction dir
frame align(frame f, pair dir) 
{
  return shift(dir)*shift(-point(f,-dir))*f;
}

struct picture {
  // The functions to do the deferred drawing.
  drawerBound[] nodes;
  
  // The coordinates in flex space to be used in sizing the picture.
  struct bounds {
    coords2 point,min,max;
    void erase() {
      point.erase();
      min.erase();
      max.erase();
    }
    bounds copy() {
      bounds b=new bounds;
      b.point=point.copy();
      b.min=min.copy();
      b.max=max.copy();
      return b;
    }
    void xclip(real Min, real Max) {
      point.xclip(Min,Max);
      min.xclip(Min,Max);
      max.xclip(Min,Max);
    }
    void yclip(real Min, real Max) {
      point.yclip(Min,Max);
      min.yclip(Min,Max);
      max.yclip(Min,Max);
    }
    void clip(pair Min, pair Max) {
      xclip(Min.x,Max.x);
      yclip(Min.y,Max.y);
    }
  }
  
  bounds operator init() {return new bounds;}
  
  bounds bounds;
    
  // Transform to be applied to this picture.
  public transform T;
  
  // Cached user-space bounding box
  public pair userMin,userMax;
  
  public ScaleT scale; // Needed by graph
  public Legend[] legend;

  // The maximum sizes in the x and y directions; zero means no restriction.
  public real xsize=0, ysize=0;
  
  // If true, the x and y directions must be scaled by the same amount.
  public bool keepAspect=true;

  void init() {
    userMin=Infinity;
    userMax=-userMin;
  }
  init();
  
  // Erase the current picture, retaining any size specification.
  void erase() {
    nodes=new drawerBound[];
    bounds.erase();
    T=identity();
    scale=new ScaleT;
    legend=new Legend[];
    init();
  }
  
  bool empty() {
    return nodes.length == 0;
  }
  
  // Cache the current user-space bounding box
  void userBox(pair min, pair max) {
    userMin=minbound(userMin,min);
    userMax=maxbound(userMax,max);
  }
  
  void add(drawerBound d) {
    uptodate(false);
    nodes.push(d);
  }

  void add(drawer d) {
    uptodate(false);
    nodes.push(new void (frame f, transform t, transform T, pair, pair) {
      d(f,t*T);
    });
  }

  void clip(drawer d) {
    uptodate(false);
    bounds.clip(userMin,userMax);
    nodes.push(new void (frame f, transform t, transform T, pair, pair) {
      d(f,t*T);
    });
  }

  // Add a point to the sizing.
  void addPoint(pair user, pair truesize=0) {
    bounds.point.push(user,truesize);
    userBox(user,user);
  }
  
  // Add a point to the sizing, accounting also for the size of the pen.
  void addPoint(pair user, pair truesize=0, pen p) {
    addPoint(user,truesize+min(p));
    addPoint(user,truesize+max(p));
  }
  
  // Add a box to the sizing.
  void addBox(pair userMin, pair userMax, pair trueMin=0, pair trueMax=0) {
    bounds.min.push(userMin,trueMin);
    bounds.max.push(userMax,trueMax);
    userBox(userMin,userMax);
  }

  // Add a (user space) path to the sizing.
  void addPath(path g) {
    addBox(min(g),max(g));
  }

  // Add a path to the sizing with the additional padding of a pen.
  void addPath(path g, pen p) {
    addBox(min(g),max(g),min(p),max(p));
  }

  void size(real x, real y, bool keepAspect=this.keepAspect) {
    xsize=x;
    ysize=y;
    this.keepAspect=keepAspect;
  }

  void size(real size, bool keepAspect=this.keepAspect) {
    xsize=size;
    ysize=size;
    this.keepAspect=keepAspect;
  }

  // The scaling in one dimension:  x --> a*x + b
  struct scaling {
    public real a,b;
    static scaling build(real a, real b) {
      scaling s=new scaling;
      s.a=a; s.b=b;
      return s;
    }
    real scale(real x) {
      return a*x+b;
    }
    real scale(coord c) {
      return scale(c.user) + c.truesize;
    }
  }

  // Calculate the minimum point in scaling the coords.
  real min(scaling s, coord[] c) {
    if (c.length > 0) {
      real m=infinity;
      for (int i=0; i < c.length; ++i)
	if (finite(c[i].user) && s.scale(c[i]) < m)
	  m=s.scale(c[i]);
      return m;
    }
    else return 0;
  }
 
  // Calculate the maximum point in scaling the coords.
  real max(scaling s, coord[] c) {
    if (c.length > 0) {
      real M=-infinity;
      for (int i=0; i < c.length; ++i)
        if (finite(c[i].user) && s.scale(c[i]) > M)
          M=s.scale(c[i]);
      return M;
    } else return 0;
  }

  // Calculate the min for the final picture, given the transform of coords.
  pair min(transform t) {
    pair a=t*(1,1)-t*(0,0), b=t*(0,0);
    scaling xs=scaling.build(a.x,b.x);
    scaling ys=scaling.build(a.y,b.y);
    return (min(min(xs,bounds.min.x),
		min(xs,bounds.max.x),
		min(xs,bounds.point.x)),
	    min(min(ys,bounds.min.y),
		min(ys,bounds.max.y),
		min(ys,bounds.point.y)));
  }

  // Calculate the max for the final picture, given the transform of coords.
  pair max(transform t) {
    pair a=t*(1,1)-t*(0,0), b=t*(0,0);
    scaling xs=scaling.build(a.x,b.x);
    scaling ys=scaling.build(a.y,b.y);
    return (max(max(xs,bounds.min.x),
		max(xs,bounds.max.x),
		max(xs,bounds.point.x)),
	    max(max(ys,bounds.min.y),
		max(ys,bounds.max.y),
		max(ys,bounds.point.y)));
  }

  // Calculate the sizing constants for the given array and maximum size.
  scaling calculateScaling(coord[] coords, real size) {
    access simplex;
    simplex.problem p=new simplex.problem;
   
    void addMinCoord(coord c) {
      // (a*user + b) + truesize >= 0:
      p.addRestriction(c.user,1,c.truesize);
    }
    void addMaxCoord(coord c) {
      // (a*user + b) + truesize <= size:
      p.addRestriction(-c.user,-1,size-c.truesize);
    }

    coord[] m=maxcoords(coords,operator >=);
    coord[] M=maxcoords(coords,operator <=);
    
    for(int i=0; i < m.length; ++i)
      addMinCoord(m[i]);
    for(int i=0; i < M.length; ++i)
      addMaxCoord(M[i]);

    int status=p.optimize();
    if (status == simplex.problem.OPTIMAL) {
      return scaling.build(p.a(),p.b());
    }
    else if (status == simplex.problem.UNBOUNDED) {
      write("warning: scaling in picture unbounded");
      return scaling.build(1,0);
    }
    else {
      write("warning: cannot fit picture to requested size...enlarging...");
      return calculateScaling(coords,sqrt(2)*size);
    }
  }

  void append(coords2 point, coords2 min, coords2 max, transform t,
	      bounds bounds) 
  {
    // Add the coord info to this picture.
    if(t == identity()) {
      point.append(bounds.point);
      min.append(bounds.min);
      max.append(bounds.max);
    } else {
      point.push(t,bounds.point,bounds.point);
      // Add in all 4 corner points, to properly size rectangular pictures.
      point.push(t,bounds.min,bounds.min);
      point.push(t,bounds.min,bounds.max);
      point.push(t,bounds.max,bounds.min);
      point.push(t,bounds.max,bounds.max);
    }
  }
  
  // Returns the transform for turning user-space pairs into true-space pairs.
  transform calculateTransform(real xsize, real ysize, bool keepAspect=true) {
    if (xsize == 0 && ysize == 0)
      return identity();
    
    coords2 Coords;
    
    append(Coords,Coords,Coords,T,bounds);
    
    if (ysize == 0) {
      scaling sx=calculateScaling(Coords.x,xsize);
      return scale(sx.a);
    }
    
    if (xsize == 0) {
      scaling sy=calculateScaling(Coords.y,ysize);
      return scale(sy.a);
    }
    
    scaling sx=calculateScaling(Coords.x,xsize);
    scaling sy=calculateScaling(Coords.y,ysize);
    if (keepAspect)
      return scale(min(sx.a,sy.a));
    else
      return xscale(sx.a)*yscale(sy.a);
  }

  transform calculateTransform() {
    return calculateTransform(xsize,ysize,keepAspect);
  }

  pair min() {
    return min(calculateTransform());
  }
  
  pair max() {
    return max(calculateTransform());
  }
  
  frame fit(transform t, transform T0=T, pair m, pair M) {
    frame f;
    for (int i=0; i < nodes.length; ++i)
      nodes[i](f,t,T0,m,M);
    return f;
  }

  // Returns a rigid version of the picture using t to transform user coords
  // into truesize coords.
  frame fit(transform t) {
    return fit(t,min(t),max(t));
  }

  // Returns the picture fit to the wanted size.
  frame fit(real xsize=this.xsize, real ysize=this.ysize,
	    bool keepAspect=this.keepAspect) {
    return fit(calculateTransform(xsize,ysize,keepAspect));
  }

  // Copies the drawing information, but not the sizing information into a new
  // picture. Warning: "fitting" this picture will not scale as a normal
  // picture would.
  picture drawcopy() {
    picture dest=new picture;
    dest.nodes=copy(nodes);
    dest.T=T;
    dest.userMin=userMin;
    dest.userMax=userMax;
    dest.scale=scale.copy();
    dest.legend=copy(legend);

    return dest;
  }

  // A deep copy of this picture.  Modifying the copied picture will not affect
  // the original.
  picture copy() {
    picture dest=drawcopy();

    dest.bounds=bounds.copy();
    
    dest.xsize=xsize; dest.ysize=ysize; dest.keepAspect=keepAspect;
    return dest;
  }

  // Add a picture to this picture, such that the user coordinates will be
  // scaled identically when fitted
  void add(picture src, bool group=true, filltype filltype=NoFill,
	   bool put=Above) {
    // Copy the picture.  Only the drawing function closures are needed, so we
    // only copy them.  This needs to be a deep copy, as src could later have
    // objects added to it that should not be included in this picture.

    if(src == this) abort("cannot add picture to itself");
    
    picture srcCopy=src.drawcopy();
    // Draw by drawing the copied picture.
    nodes.push(new void (frame f, transform t, transform T, pair m, pair M) {
      frame d=srcCopy.fit(t,T*srcCopy.T,m,M);
      add(f,d,put,filltype,group);
    });
    
    legend.append(src.legend);
    
    userBox(src.userMin,src.userMax);
    
    append(bounds.point,bounds.min,bounds.max,srcCopy.T,src.bounds);
  }
}

picture operator init() {return new picture;}

picture operator * (transform t, picture orig)
{
  picture pic=orig.copy();
  pic.T=t*pic.T;
  pair c00=t*pic.userMin;
  pair c01=t*(pic.userMin.x,pic.userMax.y);
  pair c10=t*(pic.userMax.x,pic.userMin.y);
  pair c11=t*pic.userMax;
  pic.userMin=(min(c00.x,c01.x,c10.x,c11.x),min(c00.y,c01.y,c10.y,c11.y));
  pic.userMax=(max(c00.x,c01.x,c10.x,c11.x),max(c00.y,c01.y,c10.y,c11.y));
  return pic;
}

public picture currentpicture;

void size(picture pic=currentpicture, real x, real y, 
	  bool keepAspect=pic.keepAspect)
{
  pic.size(x,y,keepAspect);
}

// Ensure that each dimension is no more than size.
void size(picture pic=currentpicture, real size,
	  bool keepAspect=pic.keepAspect)
{
  pic.size(size,size,keepAspect);
}

pair size(frame f)
{
  return max(f)-min(f);
}
				     
void begingroup(picture pic=currentpicture)
{
  pic.add(new void (frame f, transform) {
    begingroup(f);
  });
}

void endgroup(picture pic=currentpicture)
{
  pic.add(new void (frame f, transform) {
    endgroup(f);
  });
}

void Draw(picture pic=currentpicture, path g, pen p=currentpen)
{
  pic.add(new void (frame f, transform t) {
    draw(f,t*g,p);
  });
  pic.addPath(g,p);
}

void _draw(picture pic=currentpicture, path g, pen p=currentpen,
	   margin margin=NoMargin)
{
  pic.add(new void (frame f, transform t) {
    draw(f,margin(t*g,p).g,p);
  });
  pic.addPath(g,p);
}

void draw(picture pic=currentpicture, explicit path[] g, pen p=currentpen)
{
  for(int i=0; i < g.length; ++i) Draw(pic,g[i],p);
}

void fill(picture pic=currentpicture, path[] g, pen p=currentpen)
{
  g=copy(g);
  pic.add(new void (frame f, transform t) {
    fill(f,t*g,p);
  });
  for(int i=0; i < g.length; ++i) 
    pic.addPath(g[i]);
}

void latticeshade(picture pic=currentpicture, path[] g,
		  pen fillrule=currentpen, pen[][] p)
{
  g=copy(g);
  p=copy(p);
  pic.add(new void (frame f, transform t) {
    latticeshade(f,t*g,fillrule,p);
  });
  for(int i=0; i < g.length; ++i) 
    pic.addPath(g[i]);
}

void axialshade(picture pic=currentpicture, path[] g, pen pena, pair a,
		pen penb, pair b)
{
  g=copy(g);
  pic.add(new void (frame f, transform t) {
    axialshade(f,t*g,pena,t*a,penb,t*b);
  });
  for(int i=0; i < g.length; ++i) 
    pic.addPath(g[i]);
}

void radialshade(picture pic=currentpicture, path[] g, pen pena, pair a,
		 real ra, pen penb, pair b, real rb)
{
  g=copy(g);
  pic.add(new void (frame f, transform t) {
    pair A=t*a, B=t*b;
    real RA=abs(t*(a+ra)-A);
    real RB=abs(t*(b+rb)-B);
    radialshade(f,t*g,pena,A,RA,penb,B,RB);
  });
  for(int i=0; i < g.length; ++i) 
    pic.addPath(g[i]);
}

void gouraudshade(picture pic=currentpicture, path[] g,
		  pen fillrule=currentpen, pen[] p, pair[] z, int[] edges)
{
  g=copy(g);
  p=copy(p);
  z=copy(z);
  edges=copy(edges);
  pic.add(new void (frame f, transform t) {
	    gouraudshade(f,t*g,fillrule,p,t*z,edges);
  });
  for(int i=0; i < g.length; ++i) 
    pic.addPath(g[i]);
}

void filldraw(picture pic=currentpicture, path[] g, pen fillpen=currentpen,
	      pen drawpen=currentpen)
{
  begingroup(pic);
  fill(pic,g,fillpen);
  draw(pic,g,drawpen);
  endgroup(pic);
}

void clip(frame f, path[] g)
{
  clip(f,g,currentpen);
}

void clip(picture pic=currentpicture, path[] g, pen p=currentpen)
{
  g=copy(g);
  pic.userMin=maxbound(pic.userMin,min(g));
  pic.userMax=minbound(pic.userMax,max(g));
  pic.clip(new void (frame f, transform t) {
    clip(f,t*g,p);
  });
}

void unfill(picture pic=currentpicture, path[] g)
{
  g=copy(g);
  pic.clip(new void (frame f, transform t) {
    unfill(f,t*g);
  });
}

bool inside(path[] g, pair z) 
{
  return inside(g,z,currentpen);
}

// Add frame dest about origin to frame src with optional grouping
void add(pair origin, frame dest, frame src, bool group=false,
	 filltype filltype=NoFill, bool put=Above)
{
  add(dest,shift(origin)*src,group,filltype,put);
}

// Add frame src about origin to picture dest with optional grouping
void add(pair origin=0, picture dest=currentpicture, frame src,
	 bool group=true, filltype filltype=NoFill, bool put=Above)
{
  dest.add(new void (frame f, transform t) {
    add(f,shift(t*origin)*src,group,filltype,put);
  });
  dest.addBox(origin,origin,min(src),max(src));
}

// Like add(pair,picture,frame) but extend picture to accommodate frame
void attach(pair origin=0, picture dest=currentpicture, frame src,
	    bool group=true, filltype filltype=NoFill, bool put=Above)
{
  transform t=dest.calculateTransform();
  add(origin,dest,src,group,filltype,put);
  pair s=size(dest.fit(t));
  size(dest,dest.xsize != 0 ? s.x : 0,dest.ysize != 0 ? s.y : 0);
}

// Like add(pair,picture,frame) but align frame in direction dir.
void add(pair origin=0, picture dest=currentpicture, frame src, pair dir,
	 bool group=true, filltype filltype=NoFill, bool put=Above)
{
  add(origin,dest,align(src,dir),group,filltype,put);
}

// Like attach(pair,picture,frame) but align frame in direction dir.
void attach(pair origin=0, picture dest=currentpicture, frame src, pair dir,
	    bool group=true, filltype filltype=NoFill, bool put=Above)
{
  attach(origin,dest,align(src,dir),group,filltype,put);
}

// Add a picture to another such that user coordinates in both will be scaled
// identically in the shipout.
void add(picture dest, picture src, bool group=true, filltype filltype=NoFill,
	 bool put=Above)
{
  dest.add(src,group,filltype,put);
}

void add(picture src, bool group=true, filltype filltype=NoFill,
	 bool put=Above)
{
  add(currentpicture,src,group,filltype,put);
}

// Fit the picture src using the identity transformation (so user
// coordinates and truesize coordinates agree) and add it about the point
// origin to picture dest.
void add(pair origin, picture dest, picture src, bool group=true,
	 filltype filltype=NoFill, bool put=Above)
{
  add(origin,dest,src.fit(identity()),group,filltype,put);
}

void add(pair origin, picture src, bool group=true, filltype filltype=NoFill,
	 bool put=Above)
{
  add(origin,currentpicture,src,group,filltype,put);
}

void fill(pair origin, picture pic=currentpicture, path[] g, pen p=currentpen)
{
  picture opic;
  fill(opic,g,p);
  add(origin,pic,opic);
}

void postscript(picture pic=currentpicture, string s)
{
  pic.add(new void (frame f, transform) {
    postscript(f,s);
    });
}

void tex(picture pic=currentpicture, string s)
{
  pic.add(new void (frame f, transform) {
    tex(f,s);
  });
}

void layer(picture pic=currentpicture)
{
  pic.add(new void (frame f, transform) {
    layer(f);
  });
}

pair point(picture pic=currentpicture, pair dir)
{
  return pic.userMin+realmult(rectify(dir),pic.userMax-pic.userMin);
}

// Transform coordinate in [0,1]x[0,1] to current user coordinates.
pair relative(picture pic=currentpicture, pair z)
{
  pair w=(pic.userMax-pic.userMin);
  return pic.userMin+(z.x*w.x,z.y*w.y);
}

void erase(picture pic=currentpicture)
{
  uptodate(false);
  pic.erase();
}
