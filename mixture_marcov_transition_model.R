#####�L�������}���R�t���ڃ��f��####
library(MASS)
library(Matrix)
library(flexmix)
library(mclust)
library(matrixStats)
library(extraDistr)
library(reshape2)
library(dplyr)
library(plyr)
library(ggplot2)

#set.seed(90345)

####�f�[�^�̔���####
hh <- 5000   #���[�U�[��
S <- 8   #�y�[�W��
k <- 5   #������
seg <- as.numeric(rmnom(hh, 1, rep(1, k)) %*% 1:k)

##�p�����[�^�̐ݒ�
#�}���R�t���ڍs��̐ݒ�
Pr <- array(0, dim=c(S-1, S, k))
for(i in 1:k){
  for(j in 1:(S-1)){
    if(j==1){
      Pr[j, -c(j, S), i] <- extraDistr::rdirichlet(1, rep(1, S-2))   
    } else {
      Pr[j, -j, i] <- extraDistr::rdirichlet(1, rep(1, S-1))
    }
  }
}

##���[�U�[���ƂɃR���o�[�W��������܂Ńf�[�^�𒀎�����
Data_list <- list()
id_list <- list()

for(i in 1:hh){
  data <- matrix(0, nrow=1000, ncol=S)
  data[1, ] <- rmnom(1, 1, Pr[1, , seg[i]])   #1�A�N�Z�X�ڂ̃��O�𐶐�
  
  for(j in 2:1000){
    data[j, ] <- rmnom(1, 1, Pr[which(data[j-1, ]==1), , seg[i]])   #2�A�N�Z�X�ȍ~�̃��O�𐶐�
    if(data[j, S]==1) break   #�R���o�[�W�������Ă�����break
  }
  Data_list[[i]] <- data[rowSums(data) > 0, ]
  id_list[[i]] <- rep(i, sum(rowSums(data) > 0))
}
Data <- do.call(rbind, Data_list)
id <- unlist(id_list)
as.matrix(data.frame(id, Data) %>%
            dplyr::group_by(id) %>%
            dplyr::summarize_all(funs(sum)))
r <- rep(0.2, k)

####EM�A���S���Y���ŗL�������}���R�t���ڃ��f���𐄒�####
##���ڃx�N�g�����쐬
index_list <- list()
for(i in 1:hh){
  data <- Data[id==i, ]
  index <- rep(0, nrow(data))
  index[1] <- 1
  index[-1] <- data[1:(nrow(data)-1), ] %*% 1:S
  index_list[[i]] <- index
}
index_trans <- unlist(index_list)

##�ϑ��f�[�^�̑ΐ��ޓx�Ɛ��ݕϐ�z���v�Z���邽�߂̊֐�
LLobz <- function(theta, r, Data, id, index, hh, k){

  #���ݕϐ����Ƃ̖ޓx���v�Z
  LLind <- matrix(0, nrow=hh, ncol=k)
  for(j in 1:k){
    Li <- rowProds(theta[index, , j] ^ Data)
    LLind[, j] <- tapply(Li, id, prod)
  }
  
  #���ݕϐ��̊����m�����v�Z
  LLho <- matrix(r, nrow=hh, ncol=k, byrow=T) * LLind   #�ϑ��f�[�^�̖ޓx
  z <- LLho / matrix(rowSums(LLho), nrow=hh, ncol=k)   #���ݕϐ�z�̊����m��
  LL <- sum(log(rowSums(LLho)))   #�ϑ��f�[�^�̑ΐ��ޓx
  rval <- list(LLob=LL, z=z, LL=LLind)
  return(rval)
}

##�����l�̐ݒ�
#�p�����[�^�̏����l
theta <- array(0, dim=c(S-1, S, k))
for(i in 1:k){
  for(j in 1:(S-1)){
    if(j==1){
      theta[j, -c(j, S), i] <- extraDistr::rdirichlet(1, rep(5, S-2))   
    } else {
      theta[j, -j, i] <- extraDistr::rdirichlet(1, rep(5, S-1))
    }
  }
}

#�������̏����l
r <- rep(1/k, k)

#�ΐ��ޓx�̏�����
L <- LLobz(theta, r, Data, id, index_trans, hh, k)
LL1 <- L$LLob
z <- L$z

#�X�V�X�e�[�^�X
dl <- 100   #EM�X�e�b�v�ł̑ΐ��ޓx�̍��̏����l
tol <- 0.1  

##EM�A���S���Y���ŗL�������}���R�t���ڃ��f���̃p�����[�^���X�V
while(abs(dl) >= tol){   #dl��tol�ȏ�̏ꍇ�͌J��Ԃ�
  #���ݕϐ�z�̏o��
  z <- L$z   
  
  #M�X�e�b�v�̌v�Z�ƍœK��
  #theta�̐���
  theta <- array(0, dim=c(S-1, S, k))
  
  for(j in 1:k){
    #���S�f�[�^�̑ΐ��ޓx����theta�̐���ʂ��v�Z
    wt_data <- matrix(z[id, j], nrow=nrow(Data), ncol=S) * Data   #�d�ݕt���f�[�^���쐬
    theta0 <- as.matrix(data.frame(id=index_trans, data=wt_data) %>%
                          dplyr::group_by(id) %>%
                          dplyr::summarise_all(funs(sum)))[, 2:(S+1)]
    theta[, , j] <- theta0 / matrix(rowSums(theta0), nrow=S-1, ncol=S)
  }
  
  #�������𐄒�
  r <- colSums(z[id, ]) / nrow(Data)
  
  #�ϑ��f�[�^�̑ΐ��ޓx���v�Z(E�X�e�b�v)
  L <- LLobz(theta, r, Data, id, index_trans, hh, k)
  LL <- L$LLob   #�ϑ��f�[�^�̑ΐ��ޓx
  iter <- iter+1   
  dl <- LL-LL1
  LL1 <- LL
  print(LL)
}

####���茋�ʂ̊m�F####
#�p�����[�^�̐���l
round(theta, 3)   #�}���R�t���ڊm���̐���l
round(Pr, 3)   #�}���R�t���ڊm���̐^�l
round(rbind(r1=r, r0=table(seg)/sum(table(seg))), 3)   #������

#���ݕϐ��̊���
round(z, 3)   #���ݕϐ�z�̊����m��
cbind(seg1=apply(z, 1, which.max), seg0=seg)   #���肳�ꂽ���ݕϐ��Ɛ^�̐��ݕϐ�

#�K���x
LL   #�ő剻���ꂽ�ΐ��ޓx
-2*(LL) + 2*(sum(theta[, , 1] > 0)*k) #AIC




