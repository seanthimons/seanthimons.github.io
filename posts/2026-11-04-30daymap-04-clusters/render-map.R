#!/usr/bin/env Rscript
if(dir.exists('.R-library')) .libPaths(c(normalizePath('.R-library'),.libPaths()))
day04_root <- 'posts/2026-11-04-30daymap-04-clusters'
day04_config <- function() list(year=2024L, crs=26916L,
  bounds=c(xmin=-86,ymin=38,xmax=-83.7,ymax=39.5), corridor_m=20000,
  radii_m=c(3000,5000,8000), primary_m=5000, minPts=4L,
  background='#14232B',ink='#E7E1D4',muted='#AAB9BC',river='#77B6BF',
  colors=c('Chemicals / distribution'='#78B7BF','Metals'='#D89977',
    'Equipment / vehicles'='#DAC17B','Polymers / materials'='#99B087',
    'Energy / petroleum'='#B29BC4','Other sectors'='#ABB5BA'))
day04_urls <- function() c(setNames(sprintf(
  'https://data.epa.gov/efservice/downloads/tri/mv_tri_basic_download/2024_%s/csv',
  c('OH','KY','IN')),sprintf('tri-2024-%s.csv',c('OH','KY','IN'))),
  'rivers-natural-earth.geojson'=paste0('https://raw.githubusercontent.com/nvkelso/natural-earth-vector/',
  'ca96624a56bd078437bca8184e78163e5039ad19/geojson/ne_10m_rivers_lake_centerlines.geojson'))
acquire_day04 <- function(cache_dir) {
  dir.create(cache_dir,recursive=TRUE,showWarnings=FALSE)
  urls<-day04_urls();old<-options(timeout=max(240,getOption('timeout')));on.exit(options(old))
  for(f in names(urls))if(!file.exists(file.path(cache_dir,f))) {
    tmp<-file.path(cache_dir,paste0(f,'.part'))
    tryCatch({
      status<-download.file(urls[[f]],tmp,method='libcurl',mode='wb')
      if(status!=0 || !file.rename(tmp,file.path(cache_dir,f)))stop('Download failed: ',f)
    },finally=if(file.exists(tmp))unlink(tmp))
  }
}
snapshot_day04 <- function(cache_dir) {
  urls<-day04_urls()
  sources<-lapply(names(urls),function(f)list(file=f,url=urls[[f]],
    retrieved_utc=format(file.info(file.path(cache_dir,f))$mtime,tz='UTC',usetz=TRUE),
    bytes=file.info(file.path(cache_dir,f))$size,
    sha256=digest::digest(file.path(cache_dir,f),algo='sha256',file=TRUE)))
  jsonlite::write_json(list(sources=sources,note='Mutable EPA downloads and pinned Natural Earth revision; retain cached raw payloads.'),
    file.path(day04_root,'source-snapshot.json'),pretty=TRUE,auto_unbox=TRUE)
}
check_day04_snapshot <- function(cache_dir) {
  s<-jsonlite::fromJSON(file.path(day04_root,'source-snapshot.json'))$sources
  if(!setequal(s$file,names(day04_urls())))stop('Snapshot sources differ from recipe')
  for(i in seq_len(nrow(s))) {
    f<-file.path(cache_dir,s$file[i])
    if(!file.exists(f) || !identical(digest::digest(f,algo='sha256',file=TRUE),s$sha256[i]))
      stop('Missing or changed source: ',f)
  }
}
read_day04_tri <- function(cache_dir) {
  wanted<-c('YEAR','TRIFD','FRS ID','FACILITY NAME','CITY','ST','LATITUDE','LONGITUDE',
    'HORIZONTAL DATUM','INDUSTRY SECTOR')
  d<-do.call(rbind,lapply(c('OH','KY','IN'),function(state) {
    p<-file.path(cache_dir,sprintf('tri-2024-%s.csv',state))
    x<-read.csv(p,check.names=FALSE,colClasses='character',na.strings=c('','NA'),strip.white=TRUE)
    names(x)<-sub('^[0-9]+[.] ','',names(x))
    if(!all(wanted %in% names(x)) || !nrow(x))stop('Invalid TRI file: ',p)
    if(anyNA(x$YEAR) || any(x$YEAR!='2024') || any(x$ST!=state))stop('Year/state mismatch: ',p)
    x[wanted]
  }))
  if(anyNA(d$TRIFD) || any(d$TRIFD==''))stop('Missing TRI facility ID')
  d
}
collapse_day04_sites <- function(rows) {
  # Chemical rows are collapsed by TRI ID, then shared registry sites are
  # collapsed by FRS ID (a missing FRS falls back to the original TRI ID).
  ids<-sort(unique(rows$TRIFD))
  fields<-c('FRS ID','FACILITY NAME','CITY','ST','LATITUDE','LONGITUDE','HORIZONTAL DATUM')
  facilities<-lapply(ids,function(id) {
    r<-rows[rows$TRIFD==id,,drop=FALSE]
    for(f in fields)if(length(unique(r[[f]]))!=1)stop('Conflicting facility identity/coordinate: ',id,' / ',f)
    data.frame(tri_id=id,frs_id=r$`FRS ID`[1],name=r$`FACILITY NAME`[1],city=r$CITY[1],state=r$ST[1],
      lat=as.numeric(r$LATITUDE[1]),lon=as.numeric(r$LONGITUDE[1]),datum=r$`HORIZONTAL DATUM`[1],
      sectors=paste(sort(unique(r$`INDUSTRY SECTOR`)),collapse=' | '),report_rows=nrow(r))
  })
  facilities<-do.call(rbind,facilities)
  if(any(!is.finite(facilities$lat)|!is.finite(facilities$lon)) ||
     any(facilities$lat<36 | facilities$lat>43 | facilities$lon< -90 | facilities$lon> -80))
    stop('Missing or implausible facility coordinates')
  facilities$site_id<-ifelse(is.na(facilities$frs_id)|facilities$frs_id=='',
    paste0('TRI:',facilities$tri_id),paste0('FRS:',facilities$frs_id))
  sites<-lapply(sort(unique(facilities$site_id)),function(id) {
    r<-facilities[facilities$site_id==id,,drop=FALSE]
    # Shared registry IDs must agree on a location; don't average contradictory coordinates.
    if(length(unique(r$lat))!=1 || length(unique(r$lon))!=1 || length(unique(r$datum))!=1)
      stop('Shared FRS location conflict: ',id)
    data.frame(site_id=id,tri_ids=paste(sort(r$tri_id),collapse=' | '),
      tri_id_count=nrow(r),name=paste(sort(unique(r$name)),collapse=' | '),
      city=paste(sort(unique(r$city)),collapse=' | '),state=paste(sort(unique(r$state)),collapse=' | '),
      lat=r$lat[1],lon=r$lon[1],datum=r$datum[1],report_rows=sum(r$report_rows),
      sectors=paste(sort(unique(unlist(strsplit(r$sectors,' | ',fixed=TRUE)))),collapse=' | '))
  })
  list(sites=do.call(rbind,sites),tri_count=nrow(facilities),row_count=nrow(rows))
}
project_day04_sites <- function(sites) {
  # Missing datum is explicitly treated as WGS84 for this kilometer-scale study.
  # Preserve the original field and transform known NAD27/NAD83 coordinates correctly.
  assumed<-is.na(sites$datum)|sites$datum==''
  sites$datum_assumed<-assumed
  datum<-ifelse(assumed,'WGS84',sites$datum)
  crs<-c(WGS84=4326,NAD83=4269,NAD27=4267)
  if(any(!datum %in% names(crs)))stop('Unexpected horizontal datum')
  parts<-lapply(unique(datum),function(code) {
    sf::st_transform(sf::st_as_sf(sites[datum==code,],coords=c('lon','lat'),crs=crs[[code]],remove=FALSE),26916)
  })
  out<-do.call(rbind,parts);out[order(out$site_id),]
}
prepare_day04 <- function(cache_dir) {
  check_day04_snapshot(cache_dir);cfg<-day04_config()
  collapsed<-collapse_day04_sites(read_day04_tri(cache_dir))
  sites<-project_day04_sites(collapsed$sites)
  crosswalk<-read.csv(file.path(day04_root,'sector-groups.csv'),stringsAsFactors=FALSE)
  sites$sector_group<-vapply(strsplit(sites$sectors,' | ',fixed=TRUE),function(sectors) {
    groups<-unique(crosswalk$sector_group[match(sectors,crosswalk$source_sector)])
    if(anyNA(groups))stop('Unmapped TRI industry sector')
    if(length(groups)==1)groups else 'Other sectors'
  },character(1))
  rivers<-sf::st_read(file.path(cache_dir,'rivers-natural-earth.geojson'),quiet=TRUE)
  ohio<-rivers[!is.na(rivers$name) & rivers$name=='Ohio',]
  if(!nrow(ohio))stop('Missing Ohio River geometry')
  ohio<-sf::st_transform(ohio,cfg$crs)
  sites$river_distance_m<-as.numeric(sf::st_distance(sites,sf::st_union(sf::st_geometry(ohio))))
  population<-sites[sites$river_distance_m<=cfg$corridor_m,]
  roi<-sf::st_transform(sf::st_as_sfc(sf::st_bbox(cfg$bounds,crs=4326)),cfg$crs)
  visible<-lengths(sf::st_intersects(population,roi))>0
  if(!any(visible))stop('Empty map window')
  # Cluster the three-state river population BEFORE applying the display crop.
  fits<-lapply(cfg$radii_m,function(eps)dbscan::dbscan(sf::st_coordinates(population),
    eps=eps,minPts=cfg$minPts,borderPoints=TRUE))
  names(fits)<-as.character(cfg$radii_m)
  sensitivity<-do.call(rbind,lapply(seq_along(fits),function(i) {
    cl<-fits[[i]]$cluster[visible]
    data.frame(radius_km=cfg$radii_m[i]/1000,visible_sites=sum(visible),
      visible_groups=length(unique(cl[cl>0])),clustered_sites=sum(cl>0),unassigned_sites=sum(cl==0))
  }))
  for(i in seq_along(fits))population[[paste0('cluster_',cfg$radii_m[i])]]<-fits[[i]]$cluster
  # Core status is useful for inspecting density support and does not depend on cluster labels.
  for(eps in cfg$radii_m)population[[paste0('core_',eps)]]<-
    lengths(dbscan::frNN(sf::st_coordinates(population),eps=eps,sort=FALSE)$id)+1>=cfg$minPts
  context<-sf::st_transform(suppressWarnings(sf::st_crop(rivers,
    sf::st_bbox(cfg$bounds,crs=4326))),cfg$crs)
  list(population=population,visible=visible,roi=roi,ohio=ohio,context=context,
    sensitivity=sensitivity,input_rows=collapsed$row_count,input_tri_ids=collapsed$tri_count,
    input_sites=nrow(sites),input_missing_datum=sum(sites$datum_assumed),
    visible_tri_ids=sum(population$tri_id_count[visible]))
}

draw_day04 <- function(data) {
  cfg<-day04_config();p<-data$population;selected<-data$visible
  stats<-data$sensitivity[data$sensitivity$radius_km==5,]
  colors<-cfg$colors[p$sector_group]
  par(bg=cfg$background,fg=cfg$ink,col.axis=cfg$muted,family='sans',xaxs='i',yaxs='i')
  panel<-function(fig,new=TRUE)par(fig=fig,mar=rep(0,4),new=new)
  panel(c(.055,.965,.915,.99),FALSE);plot.new();plot.window(c(0,1),c(0,1))
  text(0,.85,'04 / CLUSTERS     •     THE OHIO RIVER',adj=0,col=cfg$muted,cex=.9)
  text(0,.46,'An industrial archipelago',adj=0,font=2,cex=2)
  text(0,.10,'TRI reporting sites in the Cincinnati–Louisville region  /  Reporting year 2024',adj=0,cex=.95)
  map<-function(eps,small=FALSE) {
    bb<-sf::st_bbox(data$roi)
    plot(sf::st_geometry(data$roi),col=NA,border=NA,axes=FALSE,asp=1,
      xlim=bb[c('xmin','xmax')],ylim=bb[c('ymin','ymax')])
    corridor<-sf::st_buffer(sf::st_union(sf::st_geometry(data$ohio)),cfg$corridor_m)
    plot(corridor,add=TRUE,col='#23353D',border=NA)
    plot(sf::st_geometry(data$context),add=TRUE,col='#536F7755',lwd=if(small).6 else .8)
    cl<-p[[paste0('cluster_',eps)]]
    groups<-sort(unique(cl[selected & cl>0]))
    for(group in groups) {
      halo<-sf::st_union(sf::st_buffer(sf::st_geometry(p[cl==group,]),eps/2))
      plot(halo,add=TRUE,col='#D8C38E22',border='#DDCDAA90',lwd=if(small).55 else .9)
    }
    plot(sf::st_geometry(data$ohio),add=TRUE,col=cfg$river,lwd=if(small)1 else 2)
    xy<-sf::st_coordinates(p);inside<-selected
    points(xy[inside & cl==0,,drop=FALSE],pch=1,col=unname(colors[inside & cl==0]),
      cex=if(small).38 else .8,lwd=if(small).7 else 1.1)
    points(xy[inside & cl>0,,drop=FALSE],pch=21,bg=unname(colors[inside & cl>0]),
      col=cfg$background,cex=if(small).48 else 1.05,lwd=.5)
    if(!small) {
      places<-data.frame(label=c('LOUISVILLE','CINCINNATI','Madison'),
        lon=c(-85.7585,-84.5120,-85.3799),lat=c(38.2527,39.1031,38.7359))
      places<-sf::st_transform(sf::st_as_sf(places,coords=c('lon','lat'),crs=4326),cfg$crs)
      xy<-sf::st_coordinates(places)
      # Offset labels away from the dense site clouds; anchor with thin leaders.
      tx<-xy[,1]+c(-5000,-24000,5000);ty<-xy[,2]+c(-17000,15500,9000)
      segments(xy[,1],xy[,2],tx,ty,col=cfg$muted,lwd=.65)
      text(tx,ty,places$label,col=cfg$ink,cex=c(.9,.9,.7),font=c(2,2,1))
      labels<-sf::st_transform(sf::st_as_sf(data.frame(
        label=c('INDIANA','KENTUCKY','OHIO'),lon=c(-85.65,-84.8,-84.05),
        lat=c(39.08,38.4,39.4)),coords=c('lon','lat'),crs=4326),cfg$crs)
      text(sf::st_coordinates(labels),labels$label,col='#83979C',cex=.8)
      x<-bb['xmin']+70000;y<-bb['ymin']+9000
      segments(x,y,x+25000,y,col=cfg$ink,lwd=2)
      segments(c(x,x+25000),y-1000,c(x,x+25000),y+1000,col=cfg$ink)
      text(c(x,x+25000),y+4000,c('0','25 km'),col=cfg$ink,cex=.65)
    }
  }
  panel(c(.055,.745,.325,.90));map(cfg$primary_m)
  panel(c(.77,.965,.325,.90));plot.new();plot.window(c(0,1),c(0,1))
  text(0,.965,sprintf('%s sites',sum(selected)),adj=0,cex=1.45,font=2)
  text(0,.92,sprintf('%s TRI facility IDs',data$visible_tri_ids),adj=0,col=cfg$muted,cex=.8)
  text(0,.86,sprintf('%s groups at 5 km',stats$visible_groups),adj=0,cex=1.05)
  text(0,.815,sprintf('%s grouped / %s unassigned',stats$clustered_sites,stats$unassigned_sites),
    adj=0,col=cfg$muted,cex=.78)
  text(0,.73,'INDUSTRY SECTOR',adj=0,cex=.8,col=cfg$muted)
  for(i in seq_along(cfg$colors)) {
    y<-.68-(i-1)*.052
    points(.025,y,pch=21,bg=cfg$colors[i],col=cfg$background,cex=1)
    text(.10,y,names(cfg$colors)[i],adj=0,cex=.70)
  }
  points(.025,.335,pch=21,bg=cfg$ink,col=cfg$background,cex=.9)
  text(.10,.335,'In a DBSCAN group',adj=0,cex=.7)
  points(.025,.285,pch=1,col=cfg$ink,cex=.8)
  text(.10,.285,'Not assigned to a group',adj=0,cex=.7)
  text(0,.205,'CORE RULE',adj=0,cex=.8,col=cfg$muted)
  text(0,.125,'At least 4 sites within 5 km,\nincluding the site itself.\nGroups can extend beyond 5 km.',adj=0,cex=.72)
  text(0,.025,'Halos identify groups;\nthey are not impact zones.',adj=0,cex=.72,col=cfg$muted)
  for(i in seq_along(c(3000,8000))) {
    eps<-c(3000,8000)[i];left<-if(i==1).055 else .405
    panel(c(left,left+.31,.07,.30));map(eps,TRUE)
    row<-data$sensitivity[data$sensitivity$radius_km==eps/1000,]
    mtext(sprintf('%s km  /  %s groups  /  %s unassigned',eps/1000,row$visible_groups,row$unassigned_sites),
      side=3,line=.15,cex=.75,col=cfg$ink)
  }
  panel(c(.77,.965,.07,.30));plot.new();plot.window(c(0,1),c(0,1))
  text(0,.88,'CHANGE THE DISTANCE',adj=0,cex=.8,col=cfg$muted)
  text(0,.55,'Same sites. Same colors.\nSmaller neighborhoods leave\nmore isolated sites; larger\nones join concentrations.',adj=0,cex=.78)
  text(0,.17,'Blue band: 20 km selection corridor\nRiver line: generalized centerline\nNAD83 / UTM zone 16N',adj=0,cex=.68,col=cfg$muted)
  panel(c(.055,.965,.005,.05));plot.new();plot.window(c(0,1),c(0,1))
  text(0,.75,'EPA TRI 2024 + Natural Earth  /  One marker per FRS registry site, or TRI ID where FRS is missing.',adj=0,cex=.72,col=cfg$muted)
  text(0,.25,'Reporting geography, not release quantity or exposure  /  Sean Thimons  /  #30DayMapChallenge',adj=0,cex=.72,col=cfg$muted)
}

render_day04 <- function(cache_dir='data/30daymap/2026/day04',output_dir=file.path(day04_root,'artifacts')) {
  data<-prepare_day04(cache_dir);dir.create(output_dir,recursive=TRUE,showWarnings=FALSE)
  grDevices::png(file.path(output_dir,'day04-industrial-archipelago.png'),width=3000,height=3300,res=220,type='cairo')
  tryCatch(draw_day04(data),finally=grDevices::dev.off())
  grDevices::cairo_pdf(file.path(output_dir,'day04-industrial-archipelago.pdf'),width=3000/220,height=3300/220)
  tryCatch(draw_day04(data),finally=grDevices::dev.off())
  selected<-sf::st_drop_geometry(data$population[data$visible,])
  utils::write.csv(selected,file.path(output_dir,'reporting-sites.csv'),row.names=FALSE,na='')
  utils::write.csv(data$sensitivity,file.path(output_dir,'neighborhood-comparison.csv'),row.names=FALSE)
  report<-c(data[c('input_rows','input_tri_ids','input_sites','input_missing_datum','visible_tri_ids')],
    list(analysis_sites=nrow(data$population),visible_sites=sum(data$visible),
      config=day04_config(),sensitivity=data$sensitivity,
      assumed_datum_note='Blank datum fields treated as WGS84 for kilometer-scale display/clustering; original datum retained.',
      snapshot_sha256=digest::digest(file.path(day04_root,'source-snapshot.json'),algo='sha256',file=TRUE),
      package_versions=vapply(c('sf','dbscan','jsonlite','digest'),function(p)as.character(utils::packageVersion(p)),character(1)),
      spatial_libraries=sf::sf_extSoftVersion()))
  writeLines(sub('[[:blank:]]+$','',capture.output(dput(report))),file.path(output_dir,'provenance.R'))
  print(data$sensitivity)
  invisible(report)
}
if(sys.nframe()==0L) {
  args<-commandArgs(TRUE);cache<-'data/30daymap/2026/day04'
  if('--download' %in% args)acquire_day04(cache)
  if('--snapshot' %in% args)snapshot_day04(cache)
  render_day04(cache)
}
