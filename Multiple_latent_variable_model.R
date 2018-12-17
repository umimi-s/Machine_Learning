#####Multiple lattent variable model#####
library(MASS)
library(matrixStats)
library(Matrix)
library(data.table)
library(bayesm)
library(extraDistr)
library(condMVNorm)
library(gtools)
library(dplyr)
library(ggplot2)
library(lattice)

#set.seed(78594)

####�C�ӂ̕��U�����U�s����쐬������֐�####
##���ϗʐ��K���z����̗����𔭐�������
#�C�ӂ̑��֍s������֐����`
corrM <- function(col, lower, upper, eigen_lower, eigen_upper){
  
  rho <- matrix(runif(col^2, lower, upper), col, col)
  rho[upper.tri(rho)] <- 0
  Sigma <- rho + t(rho)
  diag(Sigma) <- 1
  X.Sigma <- eigen(Sigma)
  Lambda <- diag(X.Sigma$values)
  P <- X.Sigma$vector
  
  #�V�������֍s��̒�`�ƑΊp������1�ɂ���
  Lambda.modified <- ifelse(Lambda < 0, runif(1, eigen_lower, eigen_upper), Lambda)
  x.modified <- P %*% Lambda.modified %*% t(P)
  normalization.factor <- matrix(diag(x.modified),nrow = nrow(x.modified),ncol=1)^0.5
  Sigma <- x.modified <- x.modified / (normalization.factor %*% t(normalization.factor))
  diag(Sigma) <- 1
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
##�f�[�^�̐ݒ�
k <- 15   #�N���X�^��
hh <- 5000   #���[�U�[��
pt <- rtpois(hh, rgamma(hh, 10.0, 0.55), a=0, b=Inf)   #���[�U�[������̃��R�[�h��
hhpt <- sum(pt)   #�����R�[�h��

##ID�ƃC���f�b�N�X�̐ݒ�
#ID�̐ݒ�
no <- 1:hhpt
u_id <- rep(1:hh, pt)
t_id <- as.numeric(unlist(tapply(1:hhpt, u_id, rank)))

#�C���f�b�N�X�̐ݒ�
user_list <- list()
for(i in 1:hh){
  user_list[[i]] <- which(u_id==i)
}
u_dt <- sparseMatrix(1:hhpt, u_id, x=rep(1, hhpt), dims=c(hhpt, hh))


##�����ϐ����Ó��Ȑ��l�ɂȂ�܂ŌJ��Ԃ�
rp <- 0
repeat {
  rp <- rp + 1

  ##�p�����[�^�̐ݒ�
  #���ϗʐ��K���z�̃p�����[�^��ݒ�
  mut <- mu <- rnorm(k, -0.2, 0.5)
  Covt <- Cov <- corrM(k, -0.7, 0.8, 0.05, 0.2)
  
  #��A�x�N�g���𐶐�
  betat <- beta <- rnorm(k, -0.4, 1.5)
  
  ##�����ϐ��𐶐�
  #���ϗʐ��K���z����N���X�^�𐶐�
  U <- mvrnorm(hh, mut, Cov)   
  Z <- matrix(as.numeric(U > 0), nrow=hh, ncol=k)
  mean(Z)
  
  #���W�b�g�ƑI���m����ݒ�
  logit <- as.numeric(Z[u_id, ] %*% beta)
  Prob <- exp(logit) / (1 + exp(logit))
  
  #�x���k�[�C���z���牞���ϐ��𐶐�
  y <- rbinom(hhpt, 1, Prob)
  print(mean(y))
  
  if(mean(y) > 0.2 & mean(y) < 0.4){
    break
  }
}

####�}���R�t�A�������e�J�����@��Multiple lattent variable model�𐄒�####
##�ؒf���K���z�̗����𔭐�������֐�
rtnorm <- function(mu, sigma, a, b){
  FA <- pnorm(a, mu, sigma)
  FB <- pnorm(b, mu, sigma)
  return(qnorm(runif(length(mu))*(FB-FA)+FA, mu, sigma))
}

##���ϗʐ��K���z�̏����t�����Ғl�Ə����t�����U���v�Z����֐�
cdMVN <- function(mean, Cov, dependent, U){
  
  #���U�����U�s��̃u���b�N�s����`
  Cov11 <- Cov[dependent, dependent]
  Cov12 <- Cov[dependent, -dependent, drop=FALSE]
  Cov21 <- Cov[-dependent, dependent, drop=FALSE]
  Cov22 <- Cov[-dependent, -dependent]
  
  
  #�����t�����U�Ə����t�����ς��v�Z
  CDinv <- Cov12 %*% solve(Cov22)
  CDmu <- mean[, dependent] + t(CDinv %*% t(U[, -dependent] - mean[, -dependent]))   #�����t�����ς��v�Z
  CDvar <- Cov11 - Cov12 %*% solve(Cov22) %*% Cov21   #�����t�����U���v�Z
  val <- list(CDmu=CDmu, CDvar=CDvar)
  return(val)
}

##���ϗʐ��K���z�̖��x�֐�
mvdnorm <- function(u, mu, Cov, s){
  er <- u - mu   #�덷
  Lho <- 1 / (sqrt(2*pi)^s*sqrt(det(Cov))) * exp(-1/2 * as.numeric((er %*% solve(Cov) * er) %*% rep(1, s)))
  return(Lho)
}

##�A���S���Y���̐ݒ�
R <- 5000
keep <- 2  
iter <- 0
burnin <- 1000
disp <- 10


Z




