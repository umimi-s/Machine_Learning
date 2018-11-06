#####�������K���z(Smart Shifter)#####
library(MASS)
library(mclust)
library(reshape2)
library(plyr)
library(ggplot2)
library(lattice)

####���ϗʐ��K���z�̗����𔭐�������֐����`####
#�C�ӂ̑��֍s������֐����`
corrM <- function(col, lower, upper){
  diag(1, col, col)
  
  rho <- matrix(runif(col^2, lower, upper), col, col)
  rho[upper.tri(rho)] <- 0
  Sigma <- rho + t(rho)
  diag(Sigma) <- 1
  Sigma
  (X.Sigma <- eigen(Sigma))
  (Lambda <- diag(X.Sigma$values))
  P <- X.Sigma$vector
  P %*% Lambda %*% t(P)
  
  #�V�������֍s��̒�`�ƑΊp������1�ɂ���
  (Lambda.modified <- ifelse(Lambda < 0, 10e-6, Lambda))
  x.modified <- P %*% Lambda.modified %*% t(P)
  normalization.factor <- matrix(diag(x.modified),nrow = nrow(x.modified),ncol=1)^0.5
  Sigma <- x.modified <- x.modified / (normalization.factor %*% t(normalization.factor))
  eigen(x.modified)
  diag(Sigma) <- 1
  round(Sigma, digits=3)
  return(Sigma)
}


##���֍s�񂩂番�U�����U�s����쐬����֐����`
covmatrix <- function(col, corM, lower, upper){
  m <- abs(runif(col, lower, upper))
  c <- matrix(0, col, col)
  for(i in 1:col){
    for(j in 1:col){
      c[i, j] <- sqrt(m[i]) * sqrt(m[j])
    }
  }
  diag(c) <- m
  cc <- c * corM
  #�ŗL�l�����ŋ����I�ɐ���l�s��ɏC������
  UDU <- eigen(cc)
  val <- UDU$values
  vec <- UDU$vectors
  D <- ifelse(val < 0, val + abs(val) + 0.00001, val)
  covM <- vec %*% diag(D) %*% t(vec)
  data <- list(covM, cc,  m)
  names(data) <- c("covariance", "cc", "mu")
  return(data)
}

####�f�[�^�̔���####
#set.seed(421830)
##�f�[�^�̐ݒ�
seg <- trunc(runif(5, 2, 6.3))   #�Z�O�����g��
N <- 5000   #�T���v����
col <- 8   #�����ϐ���
ca <- 5   #�J�e�S���[��

##�J�e�S���J���ϐ��̔���
p <- runif(ca, 0.2, 1.0) 
category <- apply(t(rmultinom(N, 1, p)), 1, which.max)
sortlist <- order(category)
category <- category[sortlist]
table(category)

##���ϗʐ��K������p���ĕϐ��𔭐�������
#�ϐ��ƃp�����[�^�̊i�[
Xlist <- list()
MU <- list()
covM <- list()
Z <- c()

##�J�e�S���[����уZ�O�����g���Ƃɕϐ��𔭐�
for(c in 1:ca){
  X.seg <- list()   #���X�g��������

  ##�J�e�S�����Ƃɍ������K���z�𔭐�
  ps <- runif(seg[c], 0.2, 1.0)
  n.seg <- length(category[category==c])
  seg.z <- apply(t(rmultinom(n.seg, 1, ps)), 1, which.max)
  sort.seg <- order(seg.z)
  seg.zs <- seg.z[sort.seg]

  ##���ϒl���Z�O�����g���Ƃɔ���������
  (lower <- runif(col, 40, 80))   #�ϐ��̉����l
  (upper <- lower + runif(col, 30, 60))   #�ϐ��̏���l
  mu <- runif(col*seg[c], lower, upper)   #�ϐ��̕��ϒl�𔭐�
  (MU.s <- matrix(mu, nrow=seg[c], ncol=col, byrow=T))   #�s��ɂ܂Ƃ߂�
  
  covM.s <- array(0, dim=c(col, col, seg[c]))   #���U�����U�s��̔z���������
  for(i in 1:seg[c]){  
    ##���U�����U�s����Z�O�����g���Ƃɔ���������
    #�������z���Ƃ̑��֍s����쐬
    
    cor <- corrM(col=col, lower=-0.5, upper=0.5)
    cov <- covmatrix(col=col, corM=cor, lower=min(MU.s[i, ])/1.5, upper=max(MU.s[i, ])/1.5)
    covM.s[, , i] <- cov$covariance
  
    ##�ϐ��𔭐�������
    x.seg <- round(mvrnorm(length(seg.zs[seg.zs==i]), MU.s[i, ], covM.s[, , i]), 0)
    X.seg[[i]] <- x.seg 
  }
  
  Xlist[[c]] <-  X.seg 
  MU[[c]] <- MU.s
  covM[[c]] <- covM.s
  Z <- c(Z, seg.zs)
}

##���X�g����f�[�^�t���[���ɕϊ�
X <- matrix(0, nrow=0, ncol=col)
for(c in 1:ca){
  X.cat <- do.call(rbind, Xlist[[c]])
  X <- rbind(X, X.cat)
}
Xz <- data.frame(seg=Z, cat=category, X=X)   #�f�[�^������

##�����������ϐ��̗v��
hist(Xz[Xz$cat==2, 3], breaks=25, col="grey", xlab="value", main="�������K���z")   #���z���v���b�g
by(Xz[, 3:ncol(Xz)], Xz[, 1:2], function(x) round(colMeans(x), 2))   #�J�e�S���[�Z�O�����g�ʂ̕���
by(Xz[, 3:ncol(Xz)], Xz[, 1:2], function(x) round(var(x), 2))   #�J�e�S���[�Z�O�����g�ʂ̕��U�����U�s��
by(Xz[, 3:ncol(Xz)], Xz[, 1:2], function(x) round(cov2cor(var(x)), 2))   #�J�e�S���[�Z�O�����g�ʂ̑��֍s��
by(Xz[, 3:ncol(Xz)], Xz[, 1:2], function(x) summary(x))   #�J�e�S���[�Z�O�����g�ʂ̗v�񓝌v��
table(Xz[, 2], Xz[, 1])   #�J�e�S���[�ƃZ�O�����g�̃N���X�W�v

#�J�e�S���[�ƃZ�O�����g�𖳎������ꍇ
round(colMeans(Xz[, 3:ncol(Xz)]), 2)
round(var(Xz[, 3:ncol(Xz)]), 2)
round(cor(Xz[, 3:ncol(Xz)]), 2)
summary(Xz[, 3:ncol(Xz)])


####EM�A���S���Y���ō������K���z���f��(Smart Shifter)�𐄒�####
####EM�A���S���Y���ŗp����֐����`####
##���ϗʐ��K���z�̖ޓx�֐�
dmv <- function(x, mean.vec, S){
  LLo <- 1 / (sqrt((2 * pi)^nrow(S) * det(S))) *
         exp(-as.matrix(x - mean.vec) %*% solve(S) %*% t(x - mean.vec) / 2)
  return(LLo)
}

##�ϑ��f�[�^�̑ΐ��ޓx�Ɛ��ݕϐ�z�̒�`
LLobz <- function(X, seg, mean.M, S, r){
  LLind <- matrix(0, nrow(X), ncol=seg)   #�ΐ��ޓx���i�[����s��
  
  #�������ϗʐ��K���z�̃Z�O�����g���Ƃ̖ޓx���v�Z
  for(k in 1:seg){
    mean.vec <- mean.M[k, ]
    S_s <- S[[k]]
    Li <- apply(X, 1, function(x) dmv(x=t(x), mean.vec=mean.vec, S=S_s))   #���ϗʐ��K���z�̖ޓx���v�Z
    LLi <- ifelse(Li==0, 10^-300, Li)
    LLind[, k] <- as.vector(LLi)
  }
  
  #�ΐ��ޓx�Ɛ��ݕϐ�z�̌v�Z
  LLho <- matrix(r, nrow=nrow(X), ncol=seg, byrow=T) * LLind
  z <- LLho/matrix(apply(LLho, 1, sum), nrow=nrow(X), ncol=seg)   #z�̌v�Z 
  LLsum <- sum(log(apply(matrix(r, nrow=nrow(X), ncol=seg, byrow=T) * LLind, 1, sum)))   #�ϑ��f�[�^�̑ΐ��ޓx�̘a
  rval <- list(LLob=LLsum, z=z, LL=LLind, Li=Li)
  return(rval)
}

####�J�e�S���[���ƂɃZ�O�����g�I�����܂񂾍������ϗʐ��K���z�����EM�A���S���Y��####
##�J�e�S���[�ł̃x�X�g�Z�O�����g�̃p�����[�^����l���i�[����ϐ�
aic.best <- c()
bic.best <- c()
seg.best <- c()
M.best <- list()
S.best <- list()
Z.best <- list()
r.best <- list()

for(bsc in 1:ca){
  #��������Z�O�����g��
  cat("�J�e�S���[�͍�", bsc, "������\n", "�F�߂��Ȃ��킟\n")
  seg_list <- c(2:6)  
  
  ##����l���i�[����ϐ����`
  S.seg <- list()
  M.seg <- list()
  Z.seg <- list()
  r.seg <- list()
  AIC <- c()
  BIC <- c()
  
  ##�Z�O�����g����ω������Ȃ���œK�ȃZ�O�����g����
  for(bs in 1:length(seg_list)){
    s <- seg_list[bs] 
    print(s)
    
    ##�����l�̐ݒ�
    ##kmeas�@�ŏ����l��ݒ�
    XS <- Xz[Xz$cat==bsc, 3:ncol(Xz)]
    index.f <- kmeans(x=XS, s)$cluster
    
    #���σx�N�g���ƕ��U�����U�s��̏����l���Z�O�����g���Ƃɒ����I�ɑ��
    mean.M <- matrix(0, s, ncol(XS))
    S <- list()
    for(i in 1:s){
      mean.M[i, ] <- colMeans(XS[index.f==i, ])
      S[[i]] <- var(XS[index.f==i, ])
    }
   
    #�������̏����l
    r <- as.numeric(table(index.f)/sum(table(index.f)))
    
    ##�A���S���Y���̐ݒ�
    #�ΐ��ޓx�̏�����
    L <- LLobz(X=XS, seg=s, mean.M=mean.M, S=S, r=r)
    L1 <- L$LLob
    
    #�X�V�X�e�[�^�X
    dl <- 100   #EM�X�e�b�v�ł̑ΐ��ޓx�̍��̏�����
    tol <- 0.1 
    iter <- 1
    max.iter <- 100
    Z.err <- c()
    
    ##EM�A���S���Y���ɂ�鐄��
    while(abs(dl) >= tol & iter <= max.iter){   #dl��tol�ȏ�̏ꍇ�͌J��Ԃ�
      #M�X�e�b�v�̌v�Z
      z <- L$z   #���ݕϐ�z�̏o��
      
      #���σx�N�g���ƕ��U�����U�s��𐄒�
      mean.M <- matrix(0, nrow=s, ncol=col)
      S <- list()
      for(js in 1:s){
        #���σx�N�g���𐄒�
        mean.M[js, ] <- colSums(z[, js]*XS) / rep(nrow(XS)*r[js], col)
        
        #���U�����U�s��𐄒�
        mean.v <- matrix(mean.M[js, ], nrow=nrow(XS), ncol=col, byrow=T)
        S[[js]] <- (t(z[, js]*as.matrix(XS) - z[, js]*mean.v) %*% 
                     (z[, js]*as.matrix(XS) - z[, js]*mean.v)) / sum(z[, js])
      }
      
      #�������̐���
      r <- apply(L$z, 2, sum) / nrow(XS)
      
      ##E�X�e�b�v�̌v�Z
      L <- try(LLobz(X=XS, seg=s, mean.M=mean.M, S=S, r=r), silent=TRUE)   #�ϑ��f�[�^�̑ΐ��ޓx���v�Z
      if(class(L) == "try-error") break   #�G���[����
      LL <- L$LLob   #�ϑ��f�[�^�̑ΐ��ޓx
      
      ##�A���S���Y���̍X�V
      iter <- iter+1
      dl <- LL-LL1
      LL1 <- LL
      print(LL)
    }
    
    ##���肳�ꂽ�p�����[�^���i�[
    #AIC��BIC�̌v�Z���Ċi�[
    AIC <- c(AIC, -2*LL + 2*(s*sum(1:col)+s*col))
    BIC <- c(BIC, -2*LL + log(nrow(XS))*(s*sum(1:col)+s*col))
    
    #�p�����[�^���i�[
    S.seg[[bs]] <- S
    M.seg[[bs]] <- mean.M
    if(class(try(L$z, silent=TRUE))=="try-error") {next} else {Z.seg[[bs]] <- L$z}   #error�̏ꍇ�͎��̃Z�O�����g��
    r.seg[[bs]] <- r 
  }
  
  len <- length(Z.seg)   #�G���[���N���Ă��Ȃ��Z�O�����g���擾
  s.best <- which.min(AIC[1:len])   #AIC�ōœK�ȃZ�O�����g��I��
  
  aic.best <- c(aic.best, AIC[s.best])
  bic.best <- c(bic.best, BIC[s.best])
  seg.best <- c(seg.best, (s.best+1))
  M.best[[bsc]] <- M.seg[[s.best]]
  S.best[[bsc]] <- S.seg[[s.best]]
  Z.best[[bsc]] <- Z.seg[[s.best]]
  r.best[[bsc]] <- r.seg[[s.best]]
}

####���肳�ꂽ�p�����[�^�Ɛ^�̃Z�O�����g�̔�r####
#�J�e�S���[�̒P���W�v
table(Xz$cat) 
round(table(Xz$cat) / sum(table(Xz$cat)), 3)

##���肳�ꂽ�Z�O�����g�Ɛ^�̃Z�O�����g���r
#�^�̃Z�O�����g���𒊏o
seg.t <- c()
for(i in 1:ca){
  seg.t <- c(seg.t, length(table(Xz[Xz$cat==i, 1])))
}
seg.best   #�I�����ꂽ�Z�O�����g��
seg.t   #�^�̃Z�O�����g��

##���σx�N�g���̔�r
sapply(M.best, function(x) round(x, 2))   #���肳�ꂽ���σx�N�g��
sapply(MU, function(x) round(x, 2))   #�^�̕��σx�N�g��

##���U�����U�s��̔�r
lapply(S.best[[1]], function(x) round(x, 2))   #���肳�ꂽ���U�����U�s��
round(covM[[1]], 2)   #�^�̕��U�����U�s��

##���ݕϐ�z�̒l
round(Z.best[[1]], 3)
round(Z.best[[2]], 3)
round(Z.best[[3]], 3)
round(Z.best[[4]], 3)
round(Z.best[[5]], 3)

