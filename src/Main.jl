
"""
    MITgcm(p::String)

Run MITgcm; download it if needed.
"""
function MITgcm(p::String="./",c::Cmd=`./testreport -t hs94.cs-32x32x5`)
   d=pwd()
   test=~isdir("MITgcm")
   isempty(p)&&test ? run(`git clone https://github.com/MITgcm/MITgcm`) : nothing
   cd("$p"*"MITgcm/verification/")
   run(c)
   cd(d)
end

"""
    StartWorkers(nwrkrs::Int)

Start workers if needed.
"""
function StartWorkers(nwrkrs::Int)
   set_workers = nwrkrs
   nworkers() < set_workers ? addprocs(set_workers) : nothing
   nworkers()
end

"""
    TaskDriver(indx,fn)

Broacast / distribute task (fn; e.g. task1_loop) over indices (indx; e.g. file indices)

Examples:

```
using ClimateTasks, Distributed, SparseArrays
TaskDriver(1,task1_loop)

StartWorkers(4)
@everywhere using ClimateTasks, SparseArrays
TaskDriver(1:4,task1_loop)
```

Visualize results:

```
using FortranFiles, Plots
k=1
recl=720*360*4
fil="diags_interp/ETAN/ETAN.0000000732.data"
f =  FortranFile(fil,"r",access="direct",recl=recl,convert="big-endian")
tmp=read(f,rec=k,(Float32,(720,360))); close(f)
heatmap(tmp)
```
"""
function TaskDriver(indx::Union{UnitRange{Int},Array{Int,1},Int},fn::Function)
    i=collect(indx)
    length(i)>1 ? i=distribute(i) : nothing
    isa(i,DArray) ? println(i.indices) : nothing
    fn.(i)
end

"""
    task1_loop(indx::Int)

Interpolate all variables for one record
"""
function task1_loop(indx::Int)
    task=YAML.load(open("task.yml"))
    M=load(task["Specs"]["file"])
    MetaFile=task1_loop(indx,M)
end

"""
    task1_loop(indx,M)

Loop over a subset of model output files (`filList[indx]`), apply
`MatrixInterp` (`M`) as a postprocessing step, and write the result
to file (one subfolder for each variable)
"""
function task1_loop(indx,M)
   task=YAML.load(open("task.yml"))
   dirIn=task["InputDir"][1]
   filIn=task["InputFile"][1]
   dirOut=task["OutputDir"]
   !isdir(dirOut) ? mkdir(dirOut) : nothing
   MTRX=M["MTRX"]
   msk=M[task["Specs"]["mask"]]
   siz=Tuple(task["OutputSize"])

   tmp1=readdir(dirIn)
   tmp1=filter(x -> occursin(filIn,x),tmp1)
   filList=filter(x -> occursin(".data",x),tmp1)
   maximum(indx)>length(filList) ? error("missing files: "*filIn*"*") : nothing
   filList=filList[indx]

   !isa(filList,Array) ? filList=[filList] : nothing
   nf=length(filList)
   MetaFile=filList[1]
   MetaFile=dirIn*MetaFile[1:end-5]*".meta"
   MetaFile=MetaFileRead(MetaFile)

   nv=length(MetaFile["fldList"])
   nd=MetaFile["nDims"]
   dims=Int.(MetaFile["dimList"][:,1])
   prec=MetaFile["dataprec"]

   for ff=1:nf
      fil=dirIn*filList[ff]
      #println(fil)
      fid = open(fil)
      for vv=1:nv
         tmp=Array{Float32,2}(undef,(90,1170))
         nd==3 ? tmp=Array{Float32,3}(undef,(90,1170,50)) : nothing
         read!(fid,tmp)
         tmp = hton.(tmp)
         !ismissing(msk) ? tmp=tmp.*msk : nothing
         tmp=MatrixInterp(tmp,MTRX,siz)
         tmp=Float32.(tmp)
         #
         filOut=dirOut*strip(MetaFile["fldList"][vv])*"/"
         !isdir(filOut) ? mkdir(filOut) : nothing
         filOut=filOut*strip(MetaFile["fldList"][vv])
         filOut=filOut*fil[length(dirIn*filIn)+1:end]
         #println(filOut)
         #
         nd==3 ? recl=720*360*50*4 : recl=720*360*4
         f =  FortranFile(filOut,"w",access="direct",recl=recl,convert="big-endian")
         write(f,rec=1,tmp)
         close(f)
         #to re-read file:
         #f =  FortranFile(filOut,"r",access="direct",recl=recl,convert="big-endian");
         #tmp1=read(f,rec=1,(Float32,(720,360))); close(f);
      end
      close(fid)
   end

   return MetaFile
end
