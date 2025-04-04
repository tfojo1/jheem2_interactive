
##-----------------##
##-----------------##
##-- YEAR RANGES --##
##-----------------##
##-----------------##

is.year.range <- function(x)
{
    is.character(x) & stringr::str_detect(x, "[0-9]{4}-[0-9]{4}")
}

parse.year.ranges <- function(x)
{
    if (!all(is.year.range(x)))
        stop(paste0("Error parsing year ranges: 'x' must be a character vector containing only elements with format 'yyyy-yyyy'"))
    list(start=substr(x, 1, 4), end=substr(x, 6, 9))
}

# Returns the subset of x that intersects y. If a member of x "intersects" a member of y, it overlaps entirely with the member of y.
get.range.robust.year.intersect <- function(x, y)
{
    error.prefix = "Error getting intersection of years: "
    # x is year ranges
    if(all(is.year.range(x))) {
        
        x.start.and.ends = parse.year.ranges(x)
        x.as.singles = lapply(1:length(x), function(i) {
            x.start.and.ends[['start']][[i]]:x.start.and.ends[['end']][[i]]
        })
        # y is singles
        if (all(!is.year.range(y))) {
            return(unique(x[sapply(x.as.singles, function(year.range) {all(year.range %in% y)})]))
        }
        
        # y is year ranges
        else if (all(is.year.range(y))) {
            temporary.fix = intersect(x,y)
            if (length(temporary.fix)!=0) return (temporary.fix)
            else stop(paste0(error.prefix, "intersection of two year ranges is not yet supported"))
        }
    }
    # x is singles
    else if (all(!is.year.range(x))) {
        
        # y is singles
        if (all(!is.year.range(y))) {
            return(intersect(x,y))
        }
        # y is year ranges
        else if (all(is.year.range(y))) {
            # find year ranges that have all their single years in x
            y.start.and.ends = parse.year.ranges(y)
            y.as.singles = lapply(1:length(y), function(i) {
                y.start.and.ends[['start']][[i]]:y.start.and.ends[['end']][[i]]
            })
            y.which.intersect.x = sapply(y.as.singles, function(year.range) {all(year.range %in% x)})
            y.intersect.as.singles = y.as.singles[y.which.intersect.x]
            # Return as CHARACTER!
            return (unique(as.character(unlist(y.intersect.as.singles))))
        }
    }
    else
        stop(paste0(error.prefix, "a mixture of single years and ranges is not supported"))
}


#'@title Parse
#'
#'@param
#'
#'@export
parse.year.names <- function(years, allow.partial.parsing=F)
{
    if (is.numeric(years))
    {
        if (any(ceiling(years)!=years))
            NULL
        else
            list(lower=years,
                 upper=years+1)
    }
    else if (is.character(years))
    {
        year.range.mask = grepl("^[0-9]{4}-[0-9]{4}$", years)
        single.year.mask = grepl("^[0-9]{4}$", years)
        
        if (all(!year.range.mask & !single.year.mask) ||
            !allow.partial.parsing && (any(!year.range.mask & !single.year.mask)))
            NULL
        else
        {
            rv = list(start=numeric(),
                      end=numeric(),
                      mapped.mask = year.range.mask | single.year.mask)
            
            single.years = as.numeric(years[single.year.mask])
            year.range.starts = as.numeric(substr(years[year.range.mask], 1, 4))
            year.range.ends = as.numeric(substr(years[year.range.mask], 6, 9))
            
            rv$lower[single.year.mask] = single.years
            rv$upper[single.year.mask] = single.years+1
            
            rv$lower[year.range.mask] = year.range.starts
            rv$upper[year.range.mask] = year.range.ends+1
            
            rv$lower = rv$lower[rv$mapped.mask]
            rv$upper = rv$upper[rv$mapped.mask]
            
            rv
        }
    }
    else
        NULL
}

#'@title Make Names for a Set of Age Strata
#'
#'@param endpoints A numeric vector of at least two points. endpoints[1] is the lower bound (inclusive) of the first stratum, endpoints[2] is the upper bound (exclusive) for the first stratum and the lower bound for the second stratum, etc.
#'
#'@return A character vector with length(endpoints)-1 values
#'
#'@export
make.age.strata.names <- function(endpoints=NULL,
                                  lowers=NULL,
                                  uppers=NULL)
{
    if (!is.null(lowers)) # going to (try to) use lowers + uppers
    {
        if (is.null(uppers))
            stop("If 'lowers' is specified (not NULL), 'uppers' must be specified as well")
        if (!is.null(endpoints))
            stop("You must specify EITHER 'endpoints' OR 'lowers'+'uppers' - they cannot all be non-NULL")
        
        if (!is.numeric(lowers))
            stop("'lowers' must be a numeric vector")
        if (length(lowers)==0)
            stop("'lowers' must contain at least one value")
        if (any(is.na(lowers)))
            stop("'lowers' cannot contain NA values")
        
        if (!is.numeric(uppers))
            stop("'uppers' must be a numeric vector")
        if (any(is.na(uppers)))
            stop("'uppers' cannot contain NA values")
        if (length(uppers) != length(lowers))
            stop(paste0("'uppers' (length ", length(uppers), 
                        ") must be the same length as 'lowers' (", length(lowers), ")"))
    }
    else if (!is.null(uppers)) # error - uppers but not lowers
    {
        stop("If 'uppers' is specified (not NULL), 'lowers' must be specified as well")
    }
    else # we are using endpoints
    {
        if (!is.numeric(endpoints))
            stop("'endpoints' must be a numeric vector")
        
        if (length(endpoints)<2)
            stop("'endpoints' must contain at least two values")
        
        if (any(is.na(endpoints)))
            stop("'endpoints' cannot contain NA values")
        
        lowers = endpoints[-length(endpoints)]
        uppers = endpoints[-1]
    }
    
    rv = paste0(lowers, "-", uppers-1, " years")
    rv[is.infinite(uppers)] = paste0(lowers[is.infinite(uppers)], "+ years")
    rv[(lowers+1)==uppers] = paste0(lowers, " years")
    rv[lowers==1 & uppers==2] = '1 year'
    
    rv
}



#'@title Convert Age Strata Names into Lower and Upper Bounds for Each Stratum
#'
#'@param strata.names Names of age brackets. The function knows how to parse names generated in the format given by \link{make.age.strata.names}, as well as some other common formats
#'@param allow.partial.parsing Whether to parse if only SOME of the age brackets are parseable
#'
#'@return A list with two elements, $lowers and $uppers, representing the lower (inclusive) and upper (exclusive) bounds of each age stratum
#'
#'@export
parse.age.strata.names <- function(strata.names, allow.partial.parsing=F)
{
    # Validate
    if (!is.character(strata.names))
        stop("'strata.names' must be a character vector")
    
    if (length(strata.names)==0)
        stop("'strata.names' must contain at least one value")
    
    if (any(is.na(strata.names)))
        stop("'strata.names' cannot contain NA values")
    
    # Massage out text suffixes
    years.mask = grepl(" years$", strata.names) #we'll do this first, since it's the default
    strata.names[years.mask] = substr(strata.names[years.mask], 1, nchar(strata.names[years.mask])-6)
    
    if (!all(years.mask))
    {   
        one.year.mask = grepl(" year$", strata.names) #this next, since it's also used by the default
        strata.names[one.year.mask] = substr(strata.names[one.year.mask], 1, nchar(strata.names[one.year.mask])-5)
        
        if (!all(years.mask | one.year.mask))
        {
            years.old.mask = grepl(" years old$", strata.names) #this next, since it's also used by the default
            strata.names[years.old.mask] = substr(strata.names[years.old.mask], 1, nchar(strata.names[years.old.mask])-10)
        }
    }
    
    # Divide up the three ways to parse
    # <age>+
    # <age>-<age>
    # <age>    
    
    uppers = lowers = numeric(length(strata.names))
    
    dash.position = sapply(strsplit(strata.names, ''), function(chars){
        (1:length(chars))[chars=='-'][1]
    })
    infinite.upper.mask = substr(strata.names, nchar(strata.names), nchar(strata.names)) == "+" | substr(strata.names, 1, 1)=='>'
    zero.lower.mask = substr(strata.names, 1, 1)=='<'
    age.range.mask = !is.na(dash.position)
    single.age.mask = !age.range.mask & !infinite.upper.mask & !zero.lower.mask
    
    # Parse infinite upper
    lowers[infinite.upper.mask] = suppressWarnings(as.numeric(gsub("(>=*|\\+)", '', strata.names[infinite.upper.mask])))
    uppers[infinite.upper.mask] = Inf
    
    # Parse zero lower
    lowers[zero.lower.mask] = 0
    uppers[zero.lower.mask] = suppressWarnings(as.numeric(gsub("<=*", '', strata.names[zero.lower.mask])))
    
    # Parse age range
    lowers[age.range.mask] = suppressWarnings(as.numeric(substr(strata.names[age.range.mask],
                                                                1, dash.position[age.range.mask]-1)))
    uppers[age.range.mask] = 1+suppressWarnings(as.numeric(substr(strata.names[age.range.mask],
                                                                  dash.position[age.range.mask]+1, nchar(strata.names[age.range.mask]))))
    
    
    # Parse single age
    lowers[single.age.mask] = suppressWarnings(as.numeric(strata.names[single.age.mask]))
    uppers[single.age.mask] = lowers[single.age.mask] + 1
    
    # Return
    if (all(is.na(uppers)) || all(is.na(lowers)))
        NULL
    if (!allow.partial.parsing && (any(is.na(uppers)) || any(is.na(lowers))))
        NULL
    else
    {
        mask = !is.na(uppers) & !is.na(lowers)
        list(lower=lowers[mask],
             upper=uppers[mask],
             mapped.mask = mask)
    }
}


#'@title Convert Age Strata Names to a Standard Form
#'
#'@param strata.names A character vector of names of age strata
#'
#'@details Calls \code{\link{parse.age.strata.names}} and feeds the output into \code{\link{make.age.strata.names}}
#'
#'@export
standardize.age.strata.names <- function(strata.names)
{
    parsed = parse.age.strata.names(strata.names)
    if (is.null(parsed))
        stop("Unable to parse given strata.names")
    
    make.age.strata.names(lowers=parsed$lower, uppers=parsed$upper)
}


#'@title Re-distribute counts according to one set of age brackets into a different set of age brackets
#'
#'@param counts Either (a) a dimensionless numeric vector, or (b) a numeric array, with  one dimension named "age". The "given" age brackets according to which these counts are distributed must be continuous - with no gaps between them
#'@param desired.age.brackets,given.age.brackets The age brackets according to which the ages in counts are given or desired to be restratified to. Either (1) a character vector giving names of brackets, with one name for each age bracket value or (b) a numeric vector of age endpoints, with one more element than the number of age bracket values. given.age.brackets should be present only if names(counts) is absent (if counts is a vector) or if dimnames(counts)$age is null (if counts is an array)
#'@param smooth.infinite.age.to In building a spline over counts, what value should an infinite bound in an age range be replaced with
#'@param allow.extrapolation A logical value indicating whether extrapolation should be allowed in restratifying. Extrapolating is required when one of the desired age brackets includes ages not present in any of the given age brackets
#'@param na.rm Whether NAs should be ignored in counts
#'@param method The method to be passed to \code{\link{splinefun}}. Must be a method that can produce a monotone spline (ie, either 'monoH.FC' or 'hyman')
#'@param error.prefix A character value to be prepended to any error messages
#'
#'@export
restratify.age.counts <- function(counts,
                                  desired.age.brackets,
                                  given.age.brackets = NULL,
                                  smooth.infinite.age.to = Inf,
                                  allow.extrapolation = F,
                                  na.rm = F,
                                  method=c('monoH.FC','hyman')[1],
                                  error.prefix = '')
{
    #-- Validate error.prefix --#
    if (!is.character(error.prefix) || length(error.prefix)!=1 || is.na(error.prefix))
        stop("Error in restratify.age.counts: 'error.prefix' must be a single, non-NA character value")
    error.prefix = paste0(error.prefix, "Error in restratify.age.counts: ")
    
    #-- Validate counts --#
    if (!is.numeric(counts))
        stop(paste0(error.prefix, "'counts' must be either a dimensionless numeric vector or numeric array"))
    
    given.brackets.from = "'given.age.brackets'"
    n.brackets = length(counts)
    n.brackets.from = "length(counts)"
    if (is.array(counts))
    {
        if (is.null(names(dim(counts))))
            stop(paste0(error.prefix, "If 'counts' is an array, it must have named dimensions"))
        
        if (sum(names(dim(counts))=='age')!=1)
            stop(paste0(error.prefix, "If 'counts' is an array, it must have one (and only one) dimension named 'age'"))
        
        if (is.null(dimnames(counts)$age))
        {
            if (is.null(given.age.brackets))
                stop(paste0(error.prefix, "If the dimnames for the age dimension of 'counts' are  not set, then given.age.brackets must be specified (ie, cannot be NULL)"))
        }
        else
        {
            if (!is.null(given.age.brackets))
                stop(paste0(error.prefix, "If the dimnames for the age dimension of 'counts' are set, then given.age.brackets cannot be specified (the given age brackets will be derived from the dimnames of 'counts')"))
            
            given.age.brackets = dimnames(counts)$age
            given.brackets.from = "the dimnames for the age dimension of 'counts'"
        }
        
        n.brackets = dim(counts)['age']
        n.brackets.from = "the length of the 'age' dimension of 'counts'"
        
        if (n.brackets < 2)
            stop(paste0(error.prefix, "The 'age' dimension of 'counts' must have at least two values"))
    }
    else
    {
        if (is.null(names(counts)))
        {
            if (is.null(given.age.brackets))
                stop(paste0(error.prefix, "If the names of 'counts' is not set, then given.age.brackets must be specified (ie, cannot be NULL)"))
        }
        else
        {
            if (!is.null(given.age.brackets))
                stop(paste0(error.prefix, "If the names of 'counts' are set, then given.age.brackets cannot be specified (the given age brackets will be derived from the names of 'counts')"))
            
            given.age.brackets = names(counts)
            given.brackets.from = "the names of 'counts'"
        }
        
        if (n.brackets < 2)
            stop(paste0(error.prefix, "'counts' must have at least two values"))
    }
    
    #-- Parse/Validate given.age.brackets --#
    parsed.given.brackets = parse.age.brackets(age.brackets = given.age.brackets,
                                               n.brackets = n.brackets,
                                               require.contiguous = T,
                                               smooth.infinite.age.to = smooth.infinite.age.to, 
                                               require.non.infinite.ages = T,
                                               error.prefix = error.prefix,
                                               required.length.name.for.error = n.brackets.from,
                                               age.brackets.name.for.error = given.brackets.from,
                                               allow.partial.parsing = T)
    n.brackets = parsed.given.brackets$n
    
    #-- Parse/Validate desired.age.brackets --#
    parsed.desired.brackets = parse.age.brackets(age.brackets = desired.age.brackets,
                                                 n.brackets = NA,
                                                 require.contiguous = F,
                                                 smooth.infinite.age.to = smooth.infinite.age.to,
                                                 require.non.infinite.ages = T,
                                                 error.prefix = error.prefix,
                                                 required.length.name.for.error = NA,
                                                 age.brackets.name.for.error = 'desired.age.brackets',
                                                 allow.partial.parsing = F)
    
    if (!allow.extrapolation && 
        (any(parsed.desired.brackets$lower < parsed.given.brackets$lower[1]) ||
         any(parsed.desired.brackets$upper > parsed.given.brackets$upper[n.brackets])))
        stop(paste0(error.prefix, "Cannot extrapolate counts for ages beyond the given ages (ie, less than ",
                    parsed.given.brackets$lower[1], " or greater than ", parsed.given.brackets$upper[n.brackets], ")"))
    
    #-- Make the new values --#
    
    if (is.array(counts))
    {
        orig.dim = dim(counts)
        orig.dim.names = dimnames(counts)
        if (is.null(orig.dim.names))
            orig.dim.names = lapply(orig.dim, function(d){NULL})
        
        non.age.dimensions = setdiff(names(orig.dim), 'age')
        
        raw = apply(counts, non.age.dimensions, function(val){


            # smoother = do.get.cumulative.age.counts.smoother(counts = sub.val,
            #                                                  endpoints = parsed.given.brackets$endpoints,
            #                                                  na.rm = na.rm,
            #                                                  method = method)
            #
            # smoother(parsed.desired.brackets$upper) - smoother(parsed.desired.brackets$lower)
            
            smoother = do.get.age.counts.smoother(counts = val[parsed.given.brackets$mapped.mask][parsed.given.brackets$order],
                                                  endpoints = parsed.given.brackets$endpoints,
                                                  na.rm = na.rm,
                                                  method = method,
                                                  check.consistency=F)
            
            smoother(lower = parsed.desired.brackets$lower, upper = parsed.desired.brackets$upper)
        })
        
        raw.dim = c(age = length(parsed.desired.brackets$names),
                    orig.dim[non.age.dimensions])
        raw.dim.names = c(list(age = parsed.desired.brackets$names),
                          orig.dim.names[non.age.dimensions])
        
        dim(raw) = raw.dim
        dimnames(raw) = raw.dim.names
        
        if (names(orig.dim)[1] != 'age')
        {
            new.dim.names = raw.dim.names[names(orig.dim)]
            new.dim = raw.dim[names(orig.dim)]
            
            rv = apply(raw, names(orig.dim), function(x){x})
            dim(rv) = new.dim
            dimnames(rv) = new.dim.names
        }
        else
            rv = raw
    }
    else
    {
        # smoother = do.get.cumulative.age.counts.smoother(counts = counts[parsed.given.brackets$mapped.mask][parsed.given.brackets$order],
        #                                                  endpoints = parsed.given.brackets$endpoints,
        #                                                  na.rm = na.rm,
        #                                                  method = method)
        # 
        # rv = smoother(parsed.desired.brackets$upper) - smoother(parsed.desired.brackets$lower)
        
        smoother = do.get.age.counts.smoother(counts = counts[parsed.given.brackets$mapped.mask][parsed.given.brackets$order],
                                              endpoints = parsed.given.brackets$endpoints,
                                              na.rm = na.rm,
                                              method = method,
                                              check.consistency=F)
        
        rv = smoother(lower = parsed.desired.brackets$lower, upper = parsed.desired.brackets$upper)
        
        names(rv) = parsed.desired.brackets$names
    }
    
    #-- Set the ontology mapping --#
    attr(rv, 'mapping') = create.overlapping.age.ontology.mapping(from.values = parsed.given.brackets$names, 
                                                                  to.values = parsed.desired.brackets$names)
    rv
}

#'@title Get a function that projects a smoothed cumulative count up to a given age
#'
#'@description Get a function that produces a cubic spline over the *cumulative* counts by age up to a given age
#'
#'@param counts
#'@param given.age.brackets
#'@param smooth.infinite.age.to
#'@param allow.extrapolation
#'
#'@export
get.cumulative.age.counts.smoother <- function(counts,
                                               given.age.brackets,
                                               smooth.infinite.age.to=Inf,
                                               allow.extrapolation=F,
                                               method=c('monoH.FC','hyman')[1],
                                               error.prefix = '')
{
    #-- Validate error.prefix --#
    if (!is.character(error.prefix) || length(error.prefix)!=1 || is.na(error.prefix))
        stop("Cannot run get.cumulative.age.counts.smoother() - 'error.prefix' must be a single, non-NA character value")
    
    if (nchar(error.prefix)==0)
        error.prefix = "error in get.cumulative.age.smoother() - "
    
    #-- Validate Counts --#
    if (!is.numeric(counts))
        stop(paste0(error.prefix, "'counts' must be a NUMERIC vector with at least two elements"))
    if (length(counts)<2)
        stop(paste0(error.prefix, "'counts' must be have at least TWO elements"))
    if (any(is.na(counts)))
        stop(paste0(error.prefix, "'counts' cannot contain NA values"))
    if (any(counts<0))
        stop(paste0(error.prefix, "'counts' must contain only non-negative values"))
    
    n.brackets = length(counts)
    
    #-- Parse/Validate given.age.brackets --#
    parsed.brackets = parse.age.brackets(age.brackets = given.age.brackets,
                                         n.brackets = n.brackets,
                                         require.contiguous = T,
                                         smooth.infinite.age.to = smooth.infinite.age.to,
                                         require.non.infinite.ages = T,
                                         error.prefix = error.prefix, 
                                         required.length.name.for.error = "length(counts)",
                                         age.brackets.name.for.error = 'given.age.brackets',
                                         allow.partial.parsing = T)
    counts = counts[parsed.brackets$mapped.mask][parsed.brackets$order]
    
    
    #-- Validate 'method' --#
    if (!is.character(method) || length(method)!=1 || is.na(method))
        stop(paste0(error.prefix, "'method' must be a single, non-NA character vector"))
    
    allowed.methods = c('monoH.FC','hyman')
    if (all(method!=allowed.methods))
        stop(paste0(error.prefix, "Invalid 'method' for computing an age-count smoother. Must be one of ",
                    collapse.with.or("'", allowed.methods, "'")))
    
    
    #-- Make the spline, wrap it in an error-checking function, and return --#
    
    first.endpoint = parsed.brackets$endpoints[1]
    last.endpoint = parsed.brackets$endpoints[length(parsed.brackets$endpoints)]

    function(ages){
        
        if (!is.numeric(ages) || any(is.na(ages)))
            stop("Cannot extrapolate age counts: 'ages' must be a numeric vector with no NA values")
        
        if (!allow.extrapolation && (any(ages)<first.endpoint || any(ages)>last.endpoint))
            stop(paste0("Cannot extrapolate counts for ages beyond the ages that were given in deriving the smoother (ie, less than ",
                        first.endpoint, " or greater than ", last.endpoint, ")"))
        
        fn(ages)
    }
}

do.get.age.counts.smoother <- function(counts,
                                       endpoints,
                                       na.rm,
                                       method=c('monoH.FC','hyman')[1],
                                       error.prefix='',
                                       check.consistency=F)
{
    counts.were.na = is.na(counts)
    counts[is.na(counts)] = 0
    
    if (length(counts)<2)
        stop("Cannot get age counts smoother: must have at least two counts to smooth")
    
    obs.cum.n = cumsum(counts) 
    fn = splinefun(x=endpoints, y=c(0,obs.cum.n), method=method)
    
    
    need.to.check.na = na.rm || all(!counts.were.na)
    if (need.to.check.na)
    {
        n.counts = length(counts)
        one.before.was.na = c(F,counts.were.na[-n.counts])
        one.after.was.na = c(counts.were.na[-1],F)
        count.upper = endpoints[-1]
        count.lower = endpoints[-length(endpoints)]
        
        count.upper.before = c(-Inf, count.upper[-n.counts])
        count.lower.after = c(count.lower[-1], Inf)
    }
    
    function(lowers, uppers){
        
        if (check.consistency)
        {
            if (!is.numeric(lowers) || any(is.na(lowers)))
                stop("error getting smoothed age counts: lowers must be a numeric vector with no NA values")
            
            if (!is.numeric(uppers) || any(is.na(uppers)))
                stop("error getting smoothed age counts: uppers must be a numeric vector with no NA values")
            
            if (length(lowers) != length(uppers))
                stop("error getting smoothed age counts: lowers and uppers must be the same length")
            
            if (any(uppers <= lowers))
                stop("error getting smoothed age counts: all values of lowers must be strictly LESS than the corresponding values of uppers")
        }
        
        rv = fn(uppers) - fn(lowers)
        
        # we can trust the interpolation for a lower and upper bound iff
        # (1) all the counts between the range containing the lower and the range containing the upper were not NA
        #   AND
        # (2) Either (a) The lower bound exactly lines up to a count lower bound 
        #       OR
        #           (b) The range for the first count contains the lower bound or the lower bound precedes the range for the first count
        #       OR
        #           (c) The count before the range containing the lower bound was non-NA
        #   AND
        # (3) Either (a) The upper bound exactly lines up to a count upper bounds
        #       OR
        #           (b) The range for the last count contains the upper bound or the upper bound follows the range for the last count
        #       OR
        #           (c) The count after the range containting the upper bound was non-NA
        
        if (need.to.check.na)
        {
            trust.mask = sapply(1:length(lowers), function(i){
                
                lower = lowers[i]
                upper = uppers[i]
                
                count.mask.between.lower.and.upper = lower >= count.lower & upper <= count.upper
                if (any(counts.were.na[count.mask.between.lower.and.upper])) #fails condition (1)
                    return (F)
                
                lower.meets.criterion.2.a.or.b = any(lower==count.lower) || lower < count.lower[2]
                if (!lower.meets.criterion.2.a.or.b)
                {
                    count.mask.for.lower = count.lower <= lower & count.lower.after > lower
                    count.i.for.lower = (1:n.counts)[count.mask.for.lower]
                    lower.meets.criterion.2c = !counts.were.na[count.i.for.lower-1]
                    if (!lower.meets.criterion.2c)
                        return (F)
                }
                
                upper.meets.criterion.3.a.or.b = any(upper==count.upper) || upper > count.upper[n.counts-1]
                if (!upper.meets.criterion.3.a.or.b)
                {
                    count.mask.for.upper = count.upper >= upper & count.upper.before < upper
                    count.i.for.upper = (1:n.counts)[count.mask.for.upper]
                    upper.meets.criterion.3c = !counts.were.na[count.i.for.upper+1]
                    if (!upper.meets.criterion.3c)
                        return (F)
                }
                
                T
            })
            
            rv[!trust.mask] = NA
        }
        
        
        rv
    }
}

do.get.cumulative.age.counts.smoother <- function(counts,
                                                  endpoints,
                                                  na.rm,
                                                  method=c('monoH.FC','hyman')[1],
                                                  error.prefix='')
{
    stop("Deprecated")
    na.mask = is.na(counts)
    counts[is.na(counts)] = 0
    
    # mask = !is.na(counts)
    # if (sum(mask)<2)
    #     stop(paste0(error.prefix, "Cannot fit age smoother - there must be at least two non-NA values to smooth"))
    # 
    
    obs.cum.n = cumsum(counts)
    fn = splinefun(x=endpoints, y=c(0,obs.cum.n), method=method)
    if (na.rm || all(!na.mask))
        fn
    else
    {
        function(x, deriv){
            
            rv = fn(x, deriv)
        }
    }
}

parse.age.brackets <- function(age.brackets,
                               n.brackets,
                               require.contiguous,
                               smooth.infinite.age.to,
                               require.non.infinite.ages,
                               error.prefix,
                               required.length.name.for.error,
                               age.brackets.name.for.error,
                               allow.partial.parsing)
{
    if (is.character(age.brackets))
    {
        if (any(is.na(age.brackets)))
            stop(paste0(error.prefix, var.name.for.error, " cannot contain NA values"))
        if (!is.na(n.brackets) && length(age.brackets) != n.brackets)
            stop(paste0(error.prefix, "When ", var.name.for.error, " is a character vector of age bracket names, it must have length == ", required.length.name.for.error))
        
        parsed.age.brackets = parse.age.strata.names(age.brackets, allow.partial.parsing = allow.partial.parsing)
        if (is.null(parsed.age.brackets))
            stop(paste0(error.prefix, age.brackets.name.for.error, " is not a valid set of age names"))
        
        o = order(parsed.age.brackets$lower)
        parsed.age.brackets$lower = parsed.age.brackets$lower[o]
        parsed.age.brackets$upper = parsed.age.brackets$upper[o]
        
     #   if (is.na(n.brackets))
            n.brackets = length(parsed.age.brackets$lower)
        
        if (require.contiguous && any(parsed.age.brackets$upper[-n.brackets] != parsed.age.brackets$lower[-1]))
            stop(paste0(error.prefix, "The age brackets represented by ", age.brackets.name.for.error, " must be a CONTIGUOUS set of ages with no gaps between them"))
        
        if (any(parsed.age.brackets$upper <= parsed.age.brackets$lower))
            stop(paste0(error.prefix, "Invalid age brackets given in ", age.brackets.name.for.error, ": the upper bound in each age bracket must be greater than the lower bound"))
        
        lower = parsed.age.brackets$lower
        upper = parsed.age.brackets$upper
        mapped.mask = parsed.age.brackets$mapped.mask
        
        names = age.brackets
    }    
    else if (is.numeric(age.brackets))
    {
        endpoints = age.brackets
        
        if (!is.na(n.brackets) && length(endpoints) != (n.brackets+1))
            stop(paste0(error.prefix, "If ", age.brackets.name.for.error, " is a numeric vector of endpoints, it must have length == ", required.length.name.for.error, " + 1"))
        else if (length(endpoints)<2)
            stop(paste0(error.prefix, "If ", age.brackets.name.for.error, " is a numeric vector of endpoints, it must have at least two elements"))
        
        if (any(is.na(endpoints)))
            stop(paste0(error.prefix, age.brackets.name.for.error, " cannot contain NA values"))
        if (any(endpoints<0))
            stop(paste0(error.prefix, "When ", age.brackets.name.for.error, " is a numeric vector of endpoints, it must contain only non-negative values"))
        if (any(endpoints[-1] <= endpoints[-length(endpoints)]))
            stop(paste0(error.prefix, "When ", age.brackets.name.for.error, " is a numeric vector of endpoints, it must be a strictly ascending vector"))
        
        n.brackets = length(endpoints)-1
        o = 1:n.brackets
        lower = endpoints[o]
        upper = endpoints[-1]
        
        names = make.age.strata.names(endpoints = endpoints)
        mapped.mask = rep(T, n.brackets)
    }
    else
        stop(paste0(error.prefix, age.brackets.name.for.error, " must be either a CHARACTER vector of ages names or a NUMERIC vector of age endpoints"))
    
    
    if (require.non.infinite.ages && 
        (any(is.infinite(lower)) || any(is.infinite(upper)) ))
    {
        if (!is.numeric(smooth.infinite.age.to) || length(smooth.infinite.age.to)!=1)
            stop(paste0(error.prefix, "'smooth.infinite.age.to' must be a single, numeric value"))
        
        if (is.na(smooth.infinite.age.to) || is.infinite(smooth.infinite.age.to))
            stop(paste0(error.prefix, age.brackets.name.for.error, " cannot contain infinite values unless 'smooth.infinite.age.to' is given a finite value"))
        
        if (any(smooth.infinite.age.to <= lower[!is.infinite(lower)]) ||
            any(smooth.infinite.age.to <= upper[!is.infinite(upper)]))
            stop(paste0(error.prefix, "If any ", age.brackets.name.for.error, " contain infinite bounds, 'smooth.infinite.age.to' (",
                 smooth.infinite.age.to, ") must be greater than all other (non-infinite) age values"))
        
        lower[is.infinite(lower)] = smooth.infinite.age.to
        upper[is.infinite(upper)] = smooth.infinite.age.to
    }
    
    if (require.contiguous)
        endpoints = c(lower, upper[n.brackets])
    else
        endpoints = NULL
    
    list(endpoints = endpoints,
         lower = lower,
         upper = upper,
         order = o,
         names = names,
         mapped.mask = mapped.mask,
         n = length(lower))
}

#'@export
get.age.bracket.mapping <- function(from.age.brackets,
                                    to.age.brackets,
                                    allow.incomplete.span.of.to = T,
                                    allow.incomplete.span.of.infinite.age.range = T,
                                    allow.partial.to.parsing = T,
                                    require.map.all.to = !allow.partial.to.parsing)
{
    from.bounds = parse.age.strata.names(from.age.brackets, allow.partial.parsing = allow.partial.to.parsing)
    to.bounds = parse.age.strata.names(to.age.brackets, allow.partial.parsing = F)
    
    do.create.age.or.year.ontology.mapping(from.values = from.age.brackets,
                                           to.values = to.age.brackets,
                                           from.bounds = from.bounds,
                                           to.bounds = to.bounds,
                                           dimension = 'age',
                                           require.map.all.to = require.map.all.to,
                                           allow.incomplete.span.of.to = allow.incomplete.span.of.to,
                                           allow.incomplete.span.of.infinite.range = allow.incomplete.span.of.infinite.age.range,
                                           return.mapping = F)
}