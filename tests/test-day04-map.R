# Run from repository root after the Day04 map and Quarto render.
source('posts/2026-11-04-30daymap-04-clusters/render-map.R')
cache<-'data/30daymap/2026/day04'
x<-prepare_day04(cache);p<-x$population;v<-x$visible;cfg<-day04_config()
stopifnot(x$input_rows==9718L,x$input_tri_ids==2559L,x$input_sites==2557L,
  nrow(p)==354L,sum(v)==224L,x$visible_tri_ids==225L,!anyDuplicated(p$site_id),
  sf::st_crs(p)$epsg==26916L,all(p$river_distance_m<=20000),
  all(p$sector_group %in% names(cfg$colors)),all(p$datum_assumed))
# Independent Euclidean distances verify DBSCAN's density/connectivity semantics.
D<-as.matrix(stats::dist(sf::st_coordinates(p)))
for(eps in cfg$radii_m) {
  nearby<-D<=eps;core<-rowSums(nearby)>=cfg$minPts
  cl<-p[[paste0('cluster_',eps)]]
  stopifnot(identical(unname(core),unname(p[[paste0('core_',eps)]])),all(cl[core]>0))
  expected<-integer(nrow(p));group<-0L
  for(seed in which(core))if(expected[seed]==0L) {
    group<-group+1L;todo<-seed;expected[seed]<-group
    while(length(todo)) {
      current<-todo[1];todo<-todo[-1]
      next_ids<-which(nearby[current,] & core & expected==0L)
      expected[next_ids]<-group;todo<-c(todo,next_ids)
    }
  }
  # Ignore arbitrary numeric labels; core co-membership must match.
  stopifnot(identical(outer(expected[core],expected[core],'=='),outer(cl[core],cl[core],'==')))
  for(i in which(!core)) {
    candidates<-which(nearby[i,] & core)
    if(!length(candidates))stopifnot(cl[i]==0L) else stopifnot(cl[i] %in% cl[candidates])
  }
}
stopifnot(identical(x$sensitivity$visible_groups,c(11L,11L,7L)),
  identical(x$sensitivity$clustered_sites,c(158L,193L,208L)))
# More chemical rows and shared registry IDs must not invent additional sites.
local({
  rows<-read_day04_tri(cache)[rep(1,4),]
  rows$TRIFD<-c('A','A','B','C');rows$`FRS ID`<-c('site-1','site-1','site-1',NA_character_)
  result<-collapse_day04_sites(rows)
  stopifnot(result$row_count==4L,result$tri_count==3L,nrow(result$sites)==2L,
    sum(result$sites$report_rows)==4L,sum(result$sites$tri_id_count)==3L)
  rows$LATITUDE[2]<-as.character(as.numeric(rows$LATITUDE[2])+.01)
  failure<-tryCatch({collapse_day04_sites(rows);NULL},error=identity)
  stopifnot(inherits(failure,'error'),grepl('Conflicting',conditionMessage(failure)))
})
# Snapshot changes must fail before a render can use revised source data.
local({
  scratch<-tempfile();dir.create(scratch);on.exit(unlink(scratch,recursive=TRUE))
  for(f in names(day04_urls())) {
    if(f=='tri-2024-OH.csv')writeLines('changed',file.path(scratch,f)) else
      stopifnot(file.symlink(normalizePath(file.path(cache,f)),file.path(scratch,f)))
  }
  failure<-tryCatch({check_day04_snapshot(scratch);NULL},error=identity)
  stopifnot(inherits(failure,'error'),grepl('changed source',conditionMessage(failure)))
})
selected<-read.csv(file.path(day04_root,'artifacts/reporting-sites.csv'))
stopifnot(nrow(selected)==224L,sum(selected$tri_id_count)==225L)
local({
  con<-file(file.path(day04_root,'artifacts/day04-industrial-archipelago.png'),'rb');on.exit(close(con))
  stopifnot(identical(readBin(con,'raw',8),as.raw(c(137,80,78,71,13,10,26,10))))
  seek(con,16);stopifnot(identical(readBin(con,'integer',2,size=4,endian='big'),c(3000L,3300L)))
})
freeze<-jsonlite::fromJSON(paste0('_freeze/posts/2026-11-04-30daymap-04-clusters/',
  '2026-11-04-30daymap-04-clusters/execute-results/html.json'))
stopifnot(grepl('day04-industrial-archipelago.png',freeze$result$markdown,fixed=TRUE),
  grepl('224 reporting sites',freeze$result$markdown,fixed=TRUE))
cat('PASS: snapshot, site deduplication, projected distances, independent DBSCAN reference, sensitivity, PNG and executed freeze\n')
