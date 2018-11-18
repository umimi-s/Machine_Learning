#####�X�p�[�X�K�E�V�A���O���t�B�J�����f�����O#####
library(MASS)
library(lars)
library(glmnet)
library(glasso)
library(matrixStats)
library(Matrix)
library(bayesm)
library(extraDistr)
library(reshape2)
library(dplyr)
library(plyr)
library(ggplot2)
library(igraph)

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
  D <- ifelse(val < 0, val + abs(val) + 0.00001, val)
  covM <- vec %*% diag(D) %*% t(vec)
  data <- list(covM, cc,  m)
  names(data) <- c("covariance", "cc", "mu")
  return(data)
}

####�f�[�^�̔���####
##�f�[�^�̐ݒ�
N <- 10000   #�T���v����
k <- 20   #�ϐ���
mu <- rep(0, k)   #���σx�N�g��

##���ϗʐ��K���z����f�[�^�𐶐�
Cor <- corrM(k, -0.6, 1.0, 0.1, 1.0)
Data <- mvrnorm(N, mu, Cor)
S <- cor(Data)   #�ϑ����֍s��


#####�O���t�B�J��lasso�ŃK�E�V�A���O���t�B�J�����f���𐄒�####
##�A���S���Y���̐ݒ�
tol <- 1
lambda <- 0.04   #�������p�����[�^
diff <- 100

#�����l�̐ݒ�
Sigmat <- Sigma <- S + diag(lambda, k)
Ohm <- solve(Sigma)
dl <- sum(abs(Sigma[upper.tri(Sigma)]))

#�C���f�b�N�X���쐬
index1 <- matrix(0, nrow=k, ncol=k)
index2 <- matrix(0, nrow=k, ncol=k)
for(i in 1:k){
  index1[i, ] <- c((1:k)[-i], i)
  index2[i, i] <- k
  index2[i, -i] <- 1:(k-1)
}

##�O���t�B�J��lasso�Ńp�����[�^���X�V
while(diff > tol){
  for(i in 1:k){
  
    #���͕ϐ��̓���ւ�
    Ohm_tilde <- Ohm[index1[i, ], index1[i, ]]^1/2
    Sigma_tilde <- Sigma[index1[i, ], index1[i, ]]
    S_tilde <- S[index1[i, ], index1[i, ]]
    
    #lasso��A�Ńp�����[�^�x�N�g���𐄒�
    y <- as.numeric((solve(Sigma_tilde[-k, -k])^1/2) %*% S_tilde[-k, k])
    X <- Sigma_tilde[-k, -k]^1/2
    res <- glmnet(X, y, family="gaussian", lambda=lambda, intercept=FALSE, standardize=TRUE)
    
    #���U�����U�s��𐄒�
    beta <- as.numeric(Sigma[-i, -i] %*%  res$beta)
    Sigma[-i, i] <- Sigma[i, -i] <- beta
    omega <- as.numeric(1 / (Sigma_tilde[k, k] - t(beta) %*% res$beta))
    Ohm[-i, i] <- Ohm[i, -i] <- -omega * beta
  }
  
  #��������
  dl1 <- sum(abs(Sigma[upper.tri(Sigma)]))
  diff <- abs(dl1 - dl)
  dl <- dl1
  print(diff)
}

####���֍\��������####
diag(Sigma) <- 0
Sigma <- ifelse(Sigma > 0, 1, ifelse(Sigma < 0, -1, 0))
g <- graph.adjacency(Sigma, mode="undirected")
plot(g, vertex.size=20, vertex.shape="rectangle", vertex.color="#FFFF99")


##�֐��Ő���
res <- glasso(S, lambda)
round(solve(res$wi), 2)
