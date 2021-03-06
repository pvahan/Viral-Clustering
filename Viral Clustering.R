#### Spread Virus ####
Spread_Virus = function(minDistNames, whichChange, y, samp) {
  for (j in samp) {
    if (sum(y[j] != minDistNames[,j]) != 0) {
      y[j] = sample(minDistNames[,j], 1, replace = T)
      minDistNames[whichChange[[j]]] = y[j]
    }
  }
  return(list(y = y, minDistNames = minDistNames))
}

#### Suppress Virus ####
Suppress_Virus = function(data, y, sortMinFreq, d, minDistNames, whichChange, N) {
  iter = 0
  dm = 0
  M = length(sortMinFreq)
  mu = matrix(0, nrow = M, ncol = d)
  
  for (k in sortMinFreq) {
    iter = iter + 1
    indexes = (y == k)
    if(sum(indexes) > 1) {
      mu[iter, ] = colMeans(data[y == k, ])
    } else {
      mu[iter, ] = Inf
    }
  }
  for (i in 1:N) {
    repDataI = matrix(data[i, ], nrow = M, ncol = d, byrow = T)
    dm = rowSums((repDataI - mu)^2)
    y[i] = sortMinFreq[which.min(dm)]
    minDistNames[whichChange[[i]]] = y[i]
  }
  
  return(list(y = y, minDistNames = minDistNames))
}

##### Ploting results ####
PlotResults = function(data, y, gamma, t, K, i) {
  
  ClustersbyColor = as.factor(y)
  y[order(y)] = rep(1+(1:K[i]) %% 6, table(y))
  ClustersbyShape = as.factor(y)
  print(qplot(data[, 1], data[,2], col = ClustersbyColor, shape = ClustersbyShape))
  par(mar=c(5,5,1,5)+.1)
  plot(log(y = gamma[6:(i+1)]), x = 5:i, type = "l", col="red", 
       ylab = "log(Gamma)", xlab = "Iterations", lty = 1,
       cex.lab = 1.5, cex.axis = 1.3, lwd = 2)
  whTh = which(c(1, diff(t)) != 0)
  text(x = whTh+3, y = log(gamma[2:i][whTh])-1, labels = t[whTh], cex = 1.3)
  par(new=TRUE)
  plot(K[5:i], type="l",col="blue",xaxt="n",yaxt="n",xlab="",ylab="", 
       lty = 2, lwd = 2)
  axis(4)
  mtext("Number of Clusters",side=4,line=3,  cex=1.5, cex.axis = 1.4)
  legend("topright", col=c("red","blue"),lty=1:2,
         legend=c("log(Gamma)","# of Clusters"), cex = 1.5, lwd = 2)
}


#### Main Function ####
ViralCl = function(data, l_spr, t = nrow(data), s = 30, plt = TRUE, itr = TRUE, 
                      m = floor(log2(nrow(data))), KTrue = 1, maxK = 10, eta = 1.2) {
  
  
  #### Initialization ####
  n = nrow(data); p = ncol(data); K = n; samp = sample(1:n)
  y = NULL; y[[1]] = 1:n; gamma = 1; u_spr = l_spr
  i = 0; delta  = 0;  whichChange = vector("list", n)
  rownames(data) = 1:n; data = as.matrix(data)
  
  ###### calculate similarity matrix #######
  distMat = rdist(data)
  rownames(distMat) = 1:n; colnames(distMat) = 1:n; 
  minDist = sapply(1:n, function(x) sort(distMat[-x,x])[1:m])
  minDistNames = sapply(1:n, function(x) as.numeric(names(sort(distMat[-x,x])[1:m])))
  rm(distMat)
  whichChange = sapply(1:n, function(x) which(minDistNames == x, arr.ind=T))

  
  
  while(gamma[i+1] > 10^-6) {
    i = i+1
    K[i] = length(unique(y[[i]]))
    
    if(u_spr > 0) {
      
      #### Spread Virus ####
      spreadOut = Spread_Virus(minDistNames, whichChange, y[[i]], samp)
      y[[i+1]] = spreadOut$y
      minDistNames = spreadOut$minDistNames
      u_spr = u_spr - 1
      
    } else {
      #### Suppress Virus ####
      suppressOut = Suppress_Virus(data, y[[i]], sortMinFreq, p, minDistNames, whichChange, n)
      y[[i+1]] = suppressOut$y
      minDistNames = suppressOut$minDistNames
      u_spr = l_spr    
    }
   
    
    if (i > 1) delta[i] = mean(y[[i]] != y[[i+1]]) # Calculate Delta
    if (i%%s == 0 &&  gamma[i-s+1] < gamma[i]) {   # Update t 
      t[i+1] = round(t[i]/eta)
    } else {
      t[i+1] =  t[i]
    }
    
    if (delta[i] > K[i]/t[i+1]) {                  # Update gamma
      gamma[i+1] = gamma[i]*(1+delta[i])
    } else {
      gamma[i+1] = gamma[i]/2
    }
    if(itr) print(c(K[i], gamma[i+1], i))
    
    
    #### Sampling from small cluster to high cluster ####
    sortMinFreq = as.numeric(names(sort(table(y[[i+1]]))))
    nSort = length(sortMinFreq)
    samplength = sapply(1:nSort, function(x) length(which(y[[i+1]] == sortMinFreq[x])))
    start2 = min(which(samplength > 1))
    samp2 = unlist(sapply(start2:nSort, function(x) sample(which(y[[i+1]] == sortMinFreq[x]))))
    if (start2 == 1) samp1 = numeric(0) else {
      samp1 = unlist(sample(sapply(1:(start2-1), function(x) which(y[[i+1]] == sortMinFreq[x]))))
    }
    samp = c(samp1, samp2)
        
    if (K[i] <= KTrue) break
    
  }
  
  # perform Suppress Virus until no change accurs from y_i to y_(i+1) 
  while(sum(y[[i+1]] != y[[i]]) != 0) {
    i = i+1
    K[i] = length(unique(y[[i]]))
    suppressOut = Suppress_Virus(data, y[[i]], sortMinFreq, p, minDistNames, whichChange, n)
    y[[i+1]] = suppressOut$y
  }
  
  if(plt) PlotResults(data, y[[i+1]], gamma, t, K, i)
  return(y[[i+1]])
}

out = ViralCl(data, 3, KTrue = 1, plt = F)
