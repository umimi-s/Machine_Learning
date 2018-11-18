#####Nested Latent bariable Gaussian Distribution Model#####
options(warn=2)
library(MASS)
library(mclust)
library(flexmix)
library(RMeCab)
library(matrixStats)
library(Matrix)
library(bayesm)
library(mvtnorm)
library(extraDistr)
library(reshape2)
library(dplyr)
library(plyr)
library(ggplot2)

####���ϗʐ��K���z�̗����𔭐�������֐����`####
#�C�ӂ̑��֍s������֐����`
corrM <- function(col, lower, upper, eigen_lower, eigen_upper){
  diag(1, col, col)
  
  rho <- matrix(runif(col^2, lower, upper), col, col)
  rho[upper.tri(rho)] <- 0
  Sigma <- rho + t(rho)
  diag(Sigma) <- 1
  (X.Sigma <- eigen(Sigma))
  (Lambda <- diag(X.Sigma$values))
  P <- X.Sigma$vector
  
  #�V�������֍s��̒�`�ƑΊp������1�ɂ���
  (Lambda.modified <- ifelse(Lambda < 0, runif(1, eigen_lower, eigen_upper), Lambda))
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
  D <- ifelse(val < 0, val + abs(val) + 0.01, val)
  covM <- vec %*% diag(D) %*% t(vec)
  data <- list(covM, cc,  m)
  names(data) <- c("covariance", "cc", "mu")
  return(data)
}

####�f�[�^�̐���####
##�f�[�^�̐ݒ�
k1 <- 5
k2 <- 7
d <- 1000   #�f�[�^��
w <- rpois(d, rgamma(d, 30, 0.7))
f <- sum(w)
v <- 5   #�ϐ���

#ID�̐ݒ�
d_id <- rep(1:d, w)
n_id <- c()
for(i in 1:d){
  n_id <- c(n_id, 1:w[i])
}

##�p�����[�^�̐ݒ�
#�f�B���N�����z�̃p�����[�^
alpha1 <- rep(0.4, k1)
alpha2 <- rep(0.5, k2)


#���ϗʐ��K���z�̃p�����[�^
Cov <- Covt <- array(0, dim=c(v, v, k1))
Mu <- Mut <- matrix(0, nrow=k1, ncol=v)
for(j in 1:k1){
  corr <- corrM(v, -0.8, 0.9, 0.01, 0.2)
  Cov[, , j] <- Covt[, , j] <- covmatrix(v, corr, 2^2, 4^2)$covariance
  Mu[j, ] <- Mut[j, ] <- runif(v, 10.0, 30.0)
}

#�Œ�p�����[�^
beta0 <- betat0 <- mvrnorm(k2, rep(0, v), diag(9.0, v))

#�f�B���N�����z�̃p�����[�^�𐶐�
theta1 <- thetat1 <- extraDistr::rdirichlet(d, alpha1)
theta2 <- thetat2 <- extraDistr::rdirichlet(k1, alpha2)


##LHA���f���Ɋ�Â��f�[�^�𐶐�
Data_list <- Z1_list <- Z2_list <- list()

for(i in 1:d){
  #���𐶐�
  z1 <- rmnom(w[i], 1, theta1[i, ])
  z1_vec <- as.numeric(z1 %*% 1:k1)
  
  #�Œ�p�����[�^�̊����𐶐�
  z2 <- rmnom(w[i], 1, theta2[z1_vec, ])
  z2_vec <- as.numeric(z2 %*% 1:k2)
  
  #���ϗʐ��K���z����ϑ��f�[�^�𐶐�
  mu <- Mu[z1_vec, ] + beta0[z2_vec, ]   #���σp�����[�^
  y <- matrix(0, nrow=w[i], ncol=v)
  for(j in 1:w[i]){
    y[j, ] <- mvrnorm(1, mu[j, ], Cov[, , z1_vec[j]])
  }
  
  #�f�[�^���i�[
  Data_list[[i]] <- y
  Z1_list[[i]] <- z1
  Z2_list[[i]] <- z2
}

#���X�g��ϊ�
Data <- do.call(rbind, Data_list)
Z1 <- do.call(rbind, Z1_list)
Z2 <- do.call(rbind, Z2_list)


####�ϕ��x�C�YEM�A���S���Y����HLA�𐄒�####
##���ϗʐ��K���z�̖ޓx�֐�
dmv <- function(x, mean.vec, S, S_det, S_inv){
  LLo <- (2*pi)^(-nrow(S)/2) * S_det^(-1/2) *
    exp(-1/2 * (x - mean.vec) %*% S_inv %*% (x - mean.vec))
  return(LLo)
}

##�A���S���Y���̐ݒ�
R <- 2000
keep <- 2  
iter <- 0
burnin <- 200/keep
disp <- 10

##���O���z�̐ݒ�
#���ϗʐ��K���z�̎��O���z
mu0 <- rep(0, v)
sigma0 <- 100
sigma0_inv <- 1/sigma0

#�t�E�B�V���[�g���z�̎��O���z
nu <- v + 1
V <- nu * diag(v)
inv_V <- solve(V)

#�f�B���N�����z�̎��O���z
alpha <- 1

##�p�����[�^�̐^�l
theta1 <- thetat1
theta2 <- thetat2
mu <- Mu
Cov <- Covt
beta0 <- betat0


##�����l�̐ݒ�
theta1 <- extraDistr::rdirichlet(d, rep(10.0, k1))
theta2 <- extraDistr::rdirichlet(k1, rep(10.0, k2))
mu <- mvrnorm(k1, rep(mean(Data), v), diag(2^2, v))
Cov <- array(diag(2^2, v), dim=c(v, v, k1))
beta0 <- mvrnorm(k2, rep(0, v), diag(2^2, v))

##�p�����[�^�̊i�[�p�z��
THETA1 <- array(0, dim=c(d, k1, R/keep))
THETA2 <- array(0, dim=c(k1, k2, R/keep))
MU <- array(0, dim=c(k1, v, R/keep))
BETA <- array(0, dim=c(k2, v, R/keep))
COV <- array(0, dim=c(v, v, k1, R/keep))
SEG <- matrix(0, nrow=f, ncol=k1*k2)


#�C���f�b�N�X���쐬
index_k1 <- matrix(1:(k1*k2), nrow=k1, ncol=k2, byrow=T)
index_column <- rep(1:k1, rep(k2, k1))
d_list <- d_vec <- list()
for(i in 1:d){
  d_list[[i]] <- which(d_id==i)
  d_vec[[i]] <- rep(1, length(d_list[[i]]))
}


####�M�u�X�T���v�����O�Ńp�����[�^���T���v�����O####
for(rp in 1:R){
  
  ##���ݕϐ�z���T���v�����O
  #���ϗʐ��K���z�̑ΐ��ޓx���v�Z
  Li <- matrix(0, nrow=f, ncol=k1*k2)
  for(i in 1:k1){
    for(j in 1:k2){
      Li[, index_k1[i, ][j]] <- dmvnorm(Data, mu[i, ] + beta0[j, ] , Cov[, , i], log=TRUE)
    }
  }
  
  #���ݕϐ�z�̎��O���z�̐ݒ�
  theta1_z <- log(theta1)[d_id, index_column]
  theta2_z <- matrix(as.numeric(t(log(theta2))), nrow=f, ncol=k1*k2, byrow=T)
  
  
  #���ݕϐ�z�̌v�Z
  LLi <- theta1_z + theta2_z + Li   #���ݕϐ�z�̑ΐ��ޓx
  z_par <- exp(LLi - rowMaxs(LLi))   #�ޓx�ɕϊ�
  z_rate <- z_par / rowSums(z_par)   #���ݕϐ�z
  
  #�������z������ݕϐ����T���v�����O
  Zi <- rmnom(f, 1, z_rate)
  z_vec <- as.numeric(Zi %*% 1:(k1*k2))
  
  #�p�^�[�����Ƃɐ��ݕϐ�������
  Zi1 <- matrix(0, nrow=f, ncol=k1)
  Zi2 <- matrix(0, nrow=f, ncol=k2)
  for(j in 1:k1) {Zi1[, j] <- rowSums(Zi[, index_k1[j, ]])}
  for(j in 1:k2) {Zi2[, j] <- rowSums(Zi[, index_k1[, j]])}
  z1_vec <- as.numeric(Zi1 %*% 1:k1)
  z2_vec <- as.numeric(Zi2 %*% 1:k2)
  
  #���������X�V
  r <- colSums(Zi) / f
  
  
  ##���ϗʐ��K���z�̃p�����[�^�ƌŒ�p�����[�^���X�V
  #���σx�N�g�����X�V
  index1 <- list()
  for(j in 1:k1){
    index1[[j]] <- which(Zi1[, j]==1)
    mu_par <- colSums(Data[index1[[j]], ] - beta0[as.numeric(Zi[index1[[j]], index_k1[j, ]] %*% 1:k2), ])
    mu_mean <- mu_par / (length(index1[[j]]) + sigma0_inv)   #���σp�����[�^
    mu_cov <- Cov[, , j] / (1+length(index1[[j]]))   #���σx�N�g���̕��U�����U�s��
    mu[j, ] <- mvrnorm(1, mu_mean, mu_cov)   #���ϗʐ��K���z��蕽�σx�N�g�����T���v�����O
  }
  
  #�Œ�p�����[�^���X�V
  for(j in 1:k2){
    weighted_cov <- matrix(0, nrow=v, ncol=v)
    index2 <- which(Zi2[, j]==1)
    mu_par <- colSums(Data[index2, ] - mu[as.numeric(Zi[index2, index_k1[, j]] %*% 1:k1), ])
    mu_mean <- mu_par / (length(index2) + sigma0_inv)   #���σp�����[�^
    for(l in 1:k1){
      weighted_cov <-  weighted_cov <- Cov[, , l] * mean(Zi[index2, index_k1[, j]][, l])
    }
    mu_cov <- weighted_cov / (1+length(index2))   #�Œ�p�����[�^�̕��U�����U�s��
    beta0[j, ] <- mvrnorm(1, mu_mean, mu_cov)   #���ϗʐ��K���z���Œ�p�����[�^���T���v�����O
  }
  
  #���U�����U�s��̕ϕ����㕽�ς𐄒�
  for(j in 1:k1){
    Vn <- nu + length(index1[[j]])
    er <- Data[index1[[j]], ] - mu[z1_vec[index1[[j]]], ] - beta0[as.numeric(Zi[index1[[j]], index_k1[j, ]] %*% 1:k2), ]
    R_par <- solve(V) + t(er) %*% er
    Cov[, , j] <- rwishart(Vn, solve(R_par))$IW   #�t�E�B�V���[�g���z���番�U�����U�s����T���v�����O
  }
  
  ##���ݕϐ��̊����m�����X�V
  #���̕��z���X�V
  Zi1_T <- t(Zi1)   #���ݕϐ�z�̓]�u�s��
  wsum0 <- matrix(0, nrow=d, ncol=k1)
  for(i in 1:d){
    wsum0[i, ] <- Zi1_T[, d_list[[i]]] %*% d_vec[[i]]
  }
  wsum1 <- wsum0 + alpha   #�f�B���N�����z�̃p�����[�^
  theta1 <- extraDistr::rdirichlet(d, wsum1)   #�f�B���N�����z����T���v�����O
  
  
  #�Œ�p�����[�^�̊������z�̍X�V
  for(j in 1:k1){
    wsum2 <- colSums(Zi[, index_k1[j, ]]) + alpha   #�f�B���N�����z�̃p�����[�^
    theta2[j, ] <- extraDistr::rdirichlet(1, wsum2)   #�f�B���N�����z����T���v�����O
  }
  
  ##�p�����[�^�̊i�[�ƃT���v�����O���ʂ̕\��
  #�T���v�����O���ꂽ�p�����[�^���i�[
  if(rp%%keep==0){
    #�T���v�����O���ʂ̊i�[
    mkeep <- rp/keep
    THETA1[, , mkeep] <- theta1
    THETA2[, , mkeep] <- theta2
    MU[, , mkeep] <- mu
    BETA[, , mkeep] <- beta0
    COV[, , , mkeep] <- Cov
    
    #�g�s�b�N�����̓o�[���C�����Ԃ𒴂�����i�[����
    if(rp%%keep==0 & rp >= burnin){
      SEG <- SEG + Zi
    }
    
    if(rp%%disp==0){
      #�T���v�����O���ʂ��m�F
      print(rp)
      print(sum(log(rowSums(exp(LLi)))))
      print(round(cbind(mu, Mut), 3))
      print(round(cbind(beta0, betat0), 3))
    }
  }
}

####�T���v�����O���ʂ̉����Ɨv��####
burnin <- 500/keep
RS <- R/keep

##�T���v�����O���ʂ̉���
#���ϗʐ��K���z�̃p�����[�^���v���b�g
matplot(t(MU[1, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(MU[2, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(MU[3, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(BETA[1, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(BETA[2, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(BETA[3, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")

#��ꕪ�z�̃p�����[�^���v���b�g
matplot(t(THETA1[1, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(THETA1[2, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(THETA1[3, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(THETA2[1, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(THETA2[2, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(THETA2[3, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")

##�p�����[�^�̎��㕽�ς𐄒�
#���ϗʐ��K���z�̃p�����[�^�̎��㕽��
round(t(apply(MU[, , burnin:RS], c(1, 2), mean)), 3)   #���σx�N�g��
round(t(apply(BETA[, , burnin:RS], c(1, 2), mean)), 3)   #�Œ�p�����[�^
for(j in 1:k1){
  print(apply(COV[, , j, ], c(1, 2), mean))
}

#��ꕪ�z�̃p�����[�^�̎��㕽��
round(apply(THETA1[, , burnin:RS], c(1, 2), mean), 3)
round(apply(THETA2[, , burnin:RS], c(1, 2), mean), 3)



