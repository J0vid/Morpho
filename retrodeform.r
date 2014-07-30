#' @importFrom Rvcg vcgKDtree
getLocalStretchNoArticulate <- function(mat,pairedLM,hmult=5) {
    npair <- nrow(pairedLM)
    P <- mat[pairedLM[,1],]
    Q <- mat[pairedLM[,2],]
    PhiIJ <- GetPhi(P,Q,hmult)
    
    getSi <- function(i) {
        trans <- apply(rbind(Q,P),2,weighted.mean,w=rep(PhiIJ[,i],2))
        Psweep <- sweep(P,2,trans)
        Qsweep <- sweep(Q,2,trans)
        ##calc weighted covariance matrix
        C <- cov.wt(rbind(Psweep,Qsweep),wt=rep(PhiIJ[,i],2),center=rep(0,3))$cov
        svdC <- eigen(C)
        Tinv <- svdC$vectors%*%diag(sqrt(svdC$values))%*%t(svdC$vectors)
        T <- svdC$vectors%*%diag(1/sqrt(svdC$values))%*%t(svdC$vectors)
        TP <- Psweep%*%T
        TQ <-Qsweep%*%T
        ## get orthogonal plane
        CQ <- 0
         for (j in 1:nrow(TP))
             CQ <- CQ+tcrossprod(TP[j,],TQ[j,])+ tcrossprod(TQ[j,],TP[j,])
        
        eigCQ <- eigen(CQ)
        Hstar <- Tinv%*%eigCQ$vectors
        w1 <- Hstar[,3]
        w1 <- w1/sqrt(sum(w1^2))
        n <- crossp(Hstar[,1],Hstar[,2])
        n <- n/sqrt(sum(n^2))
        if (crossprod(n,w1) < 0)
            n <- -n
        wtan <- tanplan(n)
        wtan <- cbind(wtan$z,wtan$y)
        m <- as.vector(wtan%*%t(wtan)%*%w1)
        m <- m/sqrt(sum(m^2))
        beta <- angle.calc(w1,-m)
        ny <- (w1-m)/2
        ny <- ny/sqrt(sum(ny^2))
        gamma <- (tan(beta/2))
        Si <- (gamma-1)*tcrossprod(ny)+diag(3)#
        ni <- as.vector(Si%*%w1)
        ni <- ni/sqrt(sum(ni^2))
        chk <- crossprod(ni,c(-1,0,0))
        if (chk < 0) {
            ni <- -ni
        }
        Qi <- t(rotonto(matrix(c(-1,0,0),1,3),matrix(ni,1,3),reflection = FALSE)$gam)
######
       
        return (list(Si=Si,ni=ni,Qi=Qi,PhiI=PhiIJ[,i]))
    }
    
    return(append(lapply(1:npair,getSi),list(allphi = PhiIJ)))
}
#' @export
retrodeform3d <- function(mat,pairedLM,hmult=5,alpha=0.01) {
    hmultlocal <- hmult
    npair <- nrow(pairedLM)
    P <- mat[pairedLM[,1],]
    Q <- mat[pairedLM[,2],]
    Pdiff <- lapply(1:npair,function(x){ out <- t(t(-P)+P[x,]);return(out )})
    Qdiff <- lapply(1:npair,function(x){ out <- t(t(-Q)+Q[x,]);return(out )})
    PQdiff <- lapply(1:npair,function(x){ out <- t(t(Q)-P[x,]);return(out )})
    QPdiff <- lapply(1:npair,function(x){ out <- t(t(-P)+Q[x,]);return(out )})
    precode <- getLocalStretchNoArticulate(mat,pairedLM,hmult=hmultlocal)
    PhiIJ <- GetPhi(P,Q,hmult)
    diag(PhiIJ) <- 0

    ## create normal equation system for y,z coordinates
    Amat <- -8*(1+alpha)*PhiIJ
    diagA <- 8*(1+alpha)*colSums(PhiIJ)
    diag(Amat) <- diagA

    ## create normal equation system for x coordinates
    ## create Amat for case ri = -si (x-dimension)
    ## first 2 terms
    alpha <- alpha*1
    Amatx <- -8*PhiIJ
    diag(Amatx) <- 8*colSums(PhiIJ)
    ## alpha terms
    xPhiIJ <- GetPhi(P,Q,hmult)
    Amatx1 <- xPhiIJ*8*alpha
    newphi <- matrix(8,nrow(xPhiIJ),ncol(xPhiIJ))*alpha*xPhiIJ
    diag(newphi) <- 16*alpha*diag(precode$allphi)
    diag(Amatx1) <- colSums(newphi)
    Amatx <- Amatx+Amatx1

    ##calculate constants for x y z normal equations
    QiMiPx <- QiMiQx <-QiPx <- QiQx <- NULL
    QiMiPy <- QiMiQy <- QiPy <- QiQy <- NULL
    QiMiPz <- QiMiQz <- QiPz <- QiQz <- NULL
    
    for (i in 1:npair) {
        QiMiP <- t(precode[[i]]$Qi%*%precode[[i]]$Si%*%t(Pdiff[[i]]))
        QiMiQ <- t(precode[[i]]$Qi%*%precode[[i]]$Si%*%t(Qdiff[[i]]))
        QiP <- t(precode[[i]]$Qi%*%t(PQdiff[[i]]))
        QiQ <- t(precode[[i]]$Qi%*%t(QPdiff[[i]]))
        QiMiPx <- cbind(QiMiPx,(QiMiP[,1]))
        QiMiPy <- cbind(QiMiPy,(QiMiP[,2]))
        QiMiPz <- cbind(QiMiPz,(QiMiP[,3]))
        QiMiQx <- cbind(QiMiQx,(QiMiQ[,1]))
        QiMiQy <- cbind(QiMiQy,(QiMiQ[,2]))
        QiMiQz <- cbind(QiMiQz,(QiMiQ[,3]))
        QiPx <-  cbind(QiPx,(QiP[,1]))
        QiPy <-  cbind(QiPy,(QiP[,2]))
        QiPz <-  cbind(QiPz,(QiP[,3]))
        QiQx <-  cbind(QiQx,(QiQ[,1]))
        QiQy <-  cbind(QiQy,(QiQ[,2]))
        QiQz <-  cbind(QiQz,(QiQ[,3]))
    }

    ##calculate weights for constants in normal equation (y,z coords)
    Bmat <- PhiIJ*2
    ##calculate weights for constants in normal equation x-coords
    Bmatx <- xPhiIJ*2
    diag(Bmatx) <- 4
    Bmatx <- Bmatx
    bx <- by <- bz <- 0
    ## x dim precalculation
    constPx <- Bmat*QiMiPx
    constQx <- Bmat*QiMiQx
    constQix <- alpha*Bmatx*QiQx
    constPix <- alpha*Bmatx*QiPx

    ## ydim precalculation
    constPy <- Bmat*QiMiPy
    constQy <- Bmat*QiMiQy
    constQiy <- alpha*Bmat*QiQy
    constPiy <- alpha*Bmat*QiPy

    ## z-dim precalculation
    constPz <- Bmat*QiMiPz
    constQz <- Bmat*QiMiQz
    constQiz <- alpha*Bmat*QiQz
    constPiz <- alpha*Bmat*QiPz
    
    for (i in 1:npair) {
        bx[i] <- -sum(constPx[,i])+sum(constPx[i,])+sum(constQx[,i])-sum(constQx[i,])+1*(sum(constPix[,i])+sum(constPix[i,])+sum(constQix[,i])+sum(constQix[i,]))
       
        
        by[i] <- -sum(constPy[,i])+sum(constPy[i,])-sum(constQy[,i])+sum(constQy[i,])-sum(constPiy[,i])+sum(constPiy[i,])-sum(constQiy[,i])+sum(constQiy[i,])

        
        bz[i] <- -sum(constPz[,i])+sum(constPz[i,])-sum(constQz[,i])+sum(constQz[i,])-sum(constPiz[,i])+sum(constPiz[i,])-sum(constQiz[,i])+sum(constQiz[i,])
    }
    a <- cbind(Morpho:::armaGinv(Amatx)%*%bx,Morpho:::armaGinv(Amat)%*%-by,Morpho:::armaGinv(Amat)%*%-bz)
    a1 <- a
    a1[,1] <- -a[,1]
    a <- rbind(a1,a)
    return(a)
}

GetPhi <- function(P,Q,hmult) {
    nnpd <- vcgKDtree(P,P,2)$distance[,-1]
    nnqd <- vcgKDtree(Q,Q,2)$distance[,-1]
    h <- hmult*mean(c(nnpd,nnqd))
    h2 <- h^2
    dp <- exp(-as.matrix(dist(mat[pairedLM[,1]])^2)/h2)
    dq <- exp(-as.matrix(dist(mat[pairedLM[,2]]))^2/h2)
    
    arr <- bindArr(dp,dq,along=3)
    PhiIJ <- apply(arr,1:2,min)
    diag(PhiIJ) <- 1
    return(PhiIJ)
}
