#####�x�C�W�A�����݃}���R�t���ڑ������z���f��#####
library(MASS)
library(flexmix)
library(RMeCab)
library(matrixStats)
library(Matrix)
library(bayesm)
library(extraDistr)
library(reshape2)
library(dplyr)
library(plyr)
library(ggplot2)

#set.seed(2578)

####�f�[�^�̔���####
##�f�[�^�̐ݒ�
k <- 10   #�Z�O�����g��
hh <- 5000   #���[�U�[��
item <- 500   #�A�C�e����
pt <- rpois(hh, rgamma(hh, 15, 0.7))   #���Ԑ�
pt[pt < 5] <- ceiling(runif(sum(pt < 5), 5, 10))
hhpt <- sum(pt)   #�����R�[�h��
s <- rpois(hhpt, rgamma(hhpt, 11.5, 0.8))   #�A�C�e���w����
s[s < 3] <- ceiling(runif(sum(s < 3), 3, 10))

#ID�̐ݒ�
u_id <- rep(1:hh, pt)
t_id <- c()
for(i in 1:hh) {t_id <- c(t_id, 1:pt[i])}
ID <- data.frame(no=1:hhpt, u_id, t_id)


##�p�����[�^��ݒ�
#�f�B���N�����z�̃p�����[�^
alpha01 <- seq(3.0, 0.2, length=k*5)[((1:(k*5))%%5)==0]
alpha02 <- matrix(0.3, nrow=k, ncol=k)
diag(alpha02) <- 3.5
alpha11 <- rep(0.3, item)

#�f�B���N�����z���p�����[�^�𐶐�
omegat <- omega <- extraDistr::rdirichlet(1, alpha01)   #���[�U�[��1���ڂ̃Z�O�����g
gammat <- gamma <- extraDistr::rdirichlet(k, alpha02)   #�}���R�t���ڍs��
thetat <- theta <- extraDistr::rdirichlet(k, alpha11)   #�A�C�e���w���̃p�����[�^


##���[�U�[���ƂɃA�C�e���w���s��𐶐�����
Data <- matrix(0, nrow=hhpt, ncol=item)
Z_list <- list()

for(i in 1:hh){
  if(i%%100==0){
    print(i)
  }
  z_vec <- rep(0, s[i])
  
  for(j in 1:pt[i]){
    
    ##���Ԃ��ƂɃZ�O�����g�𐶐�
    index <- which(u_id==i)[j]
    freq <- s[index]
    
    if(j==1){
      z <- rmnom(1, 1, omega)
      z_vec[j] <- as.numeric(z %*% 1:k)
    } else {
      z <- rmnom(1, 1, gamma[z_vec[j-1], ])
      z_vec[j] <- as.numeric(z %*% 1:k)
    }
    
    ##�Z�O�����g�Ɋ�Â��A�C�e���w���s��𐶐�
    wn <- colSums(rmnom(freq, 1, theta[z_vec[j], ]))
    Data[index, ] <- wn
    Z_list[[index]] <- z_vec[j]
  }
}

#���X�g�`����ϊ�
z <- unlist(Z_list)


####�}���R�t�A�������e�J�����@�Ő��݃}���R�t���ڑ������z���f���𐄒�####
#�ΐ��ޓx�̖ڕW�l
LLst <- sum(dmnom(Data, rowSums(Data), colSums(Data)/sum(Data), log=TRUE))

##�A���S���Y���̐ݒ�
R <- 10000
keep <- 2  
iter <- 0
burnin <- 1000/keep
disp <- 10

##���O���z�̐ݒ�
#�n�C�p�[�p�����[�^�̎��O���z
alpha01 <- 1 
alpha02 <- 1
beta01 <- 0.5

##�p�����[�^�̏����l
theta <- thetat
r0 <- omegat
r1 <- gammat

tf  <- colSums(Data)/sum(Data)*item
theta <- extraDistr::rdirichlet(k, tf)   #�A�C�e���w���m���̏����l
r0 <- rep(1/k, k)
par <- matrix(0.3, nrow=k, ncol=k)
diag(par) <- 2.5
r1 <- extraDistr::rdirichlet(k, par)


##�p�����[�^�̊i�[�p�z��
THETA <- array(0, dim=c(k, item, R/keep))
R0 <- matrix(0, nrow=R/keep, ncol=k)
R1 <- array(0, dim=c(k, k, R/keep))
SEG <- matrix(0, nrow=hhpt, ncol=k)
storage.mode(SEG) <- "integer"


##MCMC����p�z��
max_time <- max(t_id)
index_t11 <- which(t_id==1)
index_t21 <- list()
index_t22 <- list()
for(j in 2:max_time){
  index_t21[[j]] <- which(t_id==j)-1
  index_t22[[j]] <- which(t_id==j)
}
Data_const <- lfactorial(s) - rowSums(lfactorial(Data))   #�������z�̖��x�֐��̑ΐ��ޓx�̒萔
sparse_data <- as(Data, "CsparseMatrix")


####�M�u�X�T���v�����O�Ńp�����[�^���T���v�����O####
for(rp in 1:R){
  
  ##���R�[�h���ƂɃZ�O�����g���T���v�����O
  #�Z�O�����g���Ƃ̖ޓx�𐄒�
  theta_log <- log(t(theta))
  LLi0 <- as.matrix(Data_const + sparse_data %*% theta_log)
  LLi_max <- apply(LLi0, 1, max)
  LLi <- exp(LLi0 - LLi_max)
  
  #�Z�O�����g�����m���̐���ƃZ�O�����g�̐���
  z_rate <- matrix(0, nrow=hhpt, ncol=k)
  Zi <- matrix(0, nrow=hhpt, ncol=k)
  z_vec <- rep(0, hhpt)
  rf02 <- matrix(0, nrow=k, ncol=k) 
  
  for(j in 1:max_time){
    if(j==1){
      #�Z�O�����g�̊����m��
      LLs <- matrix(r0, nrow=length(index_t11), ncol=k, byrow=T) * LLi[index_t11, ]   #�d�ݕt���ޓx
      z_rate[index_t11, ] <- LLs / rowSums(LLs)   #�����m��
      
      #�������z���Z�O�����g�𐶐�
      Zi[index_t11, ] <- rmnom(length(index_t11), 1, z_rate[index_t11, ])
      z_vec[index_t11] <- as.numeric(Zi[index_t11, ] %*% 1:k)
      
      #�������̃p�����[�^���X�V
      rf01 <- colSums(Zi[index_t11, ])
      
    } else {
      
      #�Z�O�����g�̊����m��
      index <- index_t22[[j]]
      z_vec[index_t21[[j]]]
      LLs <- r1[z_vec[index_t21[[j]]], , drop=FALSE] * LLi[index, , drop=FALSE]   #�d�ݕt���ޓx
      z_rate[index, ] <- LLs / rowSums(LLs)   #�����m��
      
      #�������z���Z�O�����g�𐶐�
      Zi[index, ] <- rmnom(length(index), 1, z_rate[index, ])
      z_vec[index] <- as.numeric(Zi[index, ] %*% 1:k)
      
      #�������̃p�����[�^���X�V
      rf02 <- rf02 + t(Zi[index_t21[[j]], , drop=FALSE]) %*% Zi[index, , drop=FALSE]   #�}���R�t����
    }
  }
 
  #�f�B�N�������z���獬�������T���v�����O
  rf11 <- colSums(Zi[index_t11, ]) + alpha01
  rf12 <- rf02 + alpha01
  r0 <- extraDistr::rdirichlet(1, rf11)
  r1 <- extraDistr::rdirichlet(k, rf12)
  
  #�P�ꕪ�zpsi���T���v�����O
  wf0 <- matrix(0, nrow=k, ncol=item)
  for(j in 1:k){
    wf0[j, ] <- colSums(sparse_data * Zi[, j])
  }
  wf <- wf0 + alpha01
  theta <- extraDistr::rdirichlet(k, wf)

  ##�p�����[�^�̊i�[�ƃT���v�����O���ʂ̕\��
  #�T���v�����O���ꂽ�p�����[�^���i�[
  if(rp%%keep==0){
    #�T���v�����O���ʂ̊i�[
    mkeep <- rp/keep
    THETA[, , mkeep] <- theta
    R0[mkeep, ] <- r0
    R1[, , mkeep] <- r1
    
    #�g�s�b�N�����̓o�[���C�����Ԃ𒴂�����i�[����
    if(mkeep >= burnin & rp%%keep==0){
      SEG <- SEG + Zi
    }
    
    #�T���v�����O���ʂ��m�F
    if(rp%%disp==0){
      print(rp)
      print(round(cbind(theta[, 1:10], thetat[, 1:10]), 3))
      print(round(cbind(r1, gamma), 3))
    }
  }
}

####�T���v�����O���ʂ̉����Ɨv��####
burnin <- 1000/keep   #�o�[���C������
RS <- R/keep

##�T���v�����O���ʂ̉���
#�A�C�e���w���m���̃T���v�����O����
matplot(t(THETA[, 1, ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(THETA[, 50, ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(THETA[, 100, ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(THETA[, 150, ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(THETA[, 200, ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(THETA[, 250, ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(THETA[, 300, ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(THETA[, 350, ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")

#�}���R�t���ڊm���̃T���v�����O���ʂ̉���
matplot(R0, type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(R1[1, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(R1[2, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(R1[3, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(R1[4, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(R1[5, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(R1[6, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(R1[7, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(R1[8, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(R1[9, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")
matplot(t(R1[10, , ]), type="l", xlab="�T���v�����O��", ylab="�p�����[�^")


##�T���v�����O���ʂ̗v�񐄒��
#�Z�O�����g���z�̎��㐄���
seg_mu <- SEG / rowSums(SEG)
segment <- apply(seg_mu, 1, which.max)
round(cbind(z, seg=segment, seg_mu), 3)   #�Z�O�����g�����Ɛ^�̃Z�O�����g�̔�r

#�}���R�t���ڊm���̎��㐄���
round(rbind(colMeans(R0[burnin:RS, ]), omegat), 3)   #1���ڂ̍������̎��㕽��
round(cbind(apply(R1[, , burnin:RS], c(1, 2), mean), gammat), 3)   #�}���R�t���ڊm���̎��㕽��

#�A�C�e���m���̎��㐄���
item_mu <- apply(THETA[, , burnin:RS], c(1, 2), mean)   #�A�C�e���w���m���̎��㕽��
round(cbind(t(item_mu), t(thetat)), 3)

##�ΐ��ޓx�̔�r
LLi <- sum(Data_const + rowSums(seg_mu * Data %*% log(t(item_mu))))   #���ݐ��ڑ������z���f���̎��ӑΐ��ޓx
c(LLi, LLst)


