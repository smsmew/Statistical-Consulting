#2016_12_14_TW

setwd("C:/Users/User/Documents/Studium_MA/3. Semester/Statistical Consulting/R")
seal_clean <- read.csv("seal_data_cleaned.csv")
seal1 <- seal_clean[which(seal_clean$sealID=="1"),]


# functions
mllk <- function(parvect,obs,N){
  lpn <- pw2pn(parvect,N)
  gamma<-lpn$gamma
  n <- length(obs)
  allprobs <- matrix(rep(1,N*n),nrow=n)
  ind.step <- which(!is.na(obs))
  for (j in 1:N){
    step.prob <- rep(1,n)
    step.prob[ind.step] <- dgamma(obs[ind.step],shape=lpn$mu[j]^2/lpn$sigma[j]^2,scale=lpn$sigma[j]^2/lpn$mu[j])
    allprobs[,j] <- step.prob
  }
  foo <- lpn$delta  
  lscale <- 0
  lscale <- forwardalgo(foo, gamma, allprobs, lscale, n)
  return(-lscale)
}

mle <- function(obs,mu0,sigma0,gamma0,N){
  parvect <- pn2pw(mu0,sigma0,gamma0,N)
  mod <- nlm(mllk,parvect,obs,N,print.level=2,iterlim=1000,stepmax=5)
  pn <- pw2pn(mod$estimate,N)
  return(list(mu=pn$mu,sigma=pn$sigma,gamma=pn$gamma,delta=pn$delta,mllk=mod$minimum))
}

## function that converts 'natural' parameters (possibly constrained) to 'working' parameters (all of which are real-valued) - this is only necessary since I use the unconstrained optimizer nlm() below 
pn2pw <- function(mu,sigma,gamma,N){
  tmu <- log(mu)
  tsigma <- log(sigma)
  tgamma <- NULL
  if(N>1){
    foo <- log(gamma/diag(gamma))           ### gamma ist eine Matrix!
    tgamma <- as.vector(foo[!diag(N)])
  }
  parvect <- c(tmu,tsigma,tgamma)
  return(parvect)
}
## function that performs the inverse transformation
pw2pn <- function(parvect,N){
  mu <- exp(parvect[1:N])
  sigma <- exp(parvect[(N+1):(2*N)])
  gamma <- diag(N)
  if(N>1){
    gamma[!gamma] <- exp(parvect[(2*N+1):(N+N^2)])
    gamma <- gamma/apply(gamma,1,sum)                 ### gamma = Matrix
  }
  delta <- solve(t(diag(N)-gamma+1),rep(1,N))
  return(list(mu=mu,sigma=sigma,gamma=gamma,delta=delta))
}

aic.mod <- function(mod){
  llk <- mod$mllk
  params <- length(mod$mu)+length(mod$sigma)+length(mod$mu)*(length(mod$mu)-1)
  aic <- 2*llk+2*params
  return(aic)
}

bic.mod <- function(mod,len){ #len should be the length of the data
  llk <- mod$mllk
  params <- length(mod$mu)+length(mod$sigma)+length(mod$mu)*(length(mod$mu)-1)
  bic <- 2*llk+log(len)*params
  return(bic)
}

#viterbi
viterbi<-function(obs,mod,N){
  #get parameters
  #function to convert to working parameters needs to be implemented!
  mu <- mod$mu
  sigma <- mod$sigma
  gamma <- mod$gamma
  delta <- mod$delta
  #actual algorithm
  T <- length(obs)
  xi <- matrix(0,as.integer(T),N)
  u <- delta%*%diag(N)
  xi[1,] <- u/sum(u)
  #calculate and return most likely states
  for (t in 2:T){
    Gamma <- gamma
    P<-diag(dgamma(obs[t],shape=mu^2/sigma^2,scale=sigma^2/mu))
    u<-apply(xi[t-1,]*Gamma,2,max)%*%P
    xi[t,] <- u/sum(u)
  }
  iv<-numeric(T)
  iv[T] <-which.max(xi[T,])
  for (t in (T-1):1){ 
    Gamma <- gamma
    iv[t] <- which.max(Gamma[,iv[t+1]]*xi[t,])
  }
  return(iv)
}

plot_viterbi <- function(stateobj,obs,mod,N){
  mu <- mod$mu
  for(i in 1:N){
    stateobj[stateobj==i]<-mu[i]
  }
  plot(obs,type="l",col="blue")
  points(stateobj,pch=20)
}

# Beispiel
mod <- mle(obs=seal1$steplen[1:500], c(30, 50, 70), c(10, 20, 5), matrix(rep(c(0.6, 0.2, 0.2), 3), nrow=3, byrow = T), 3)

llks<-rep(NA,20)
mu_out <- matrix(nrow = 20, ncol = N)
sig_out <- matrix(nrow = 20, ncol = N)
gamma_out <- list()
for (runs in 1:20){
  mu<-runif(N,10,150)
  sig<-runif(N,1,400)
  gamma<-matrix(runif(N^2,0,1), nrow = N)
  gamma <- gamma/apply(gamma,1,sum)  
  mod <- mle(obs=seal1$steplen[1:500], mu, sig, gamma, N)
  llks[runs] <- mod$mllk
  for (i in 1:N) {
    mu_out[runs, i] <- mod$mu[i]
    sig_out[runs, i] <- mod$sigma[i]
  }
  gamma_out[runs] <-  mod$gamma
}

# one full example
mod <- mle(obs=seal1$steplen[1:500], c(30, 50, 70), c(10, 20, 5), matrix(rep(c(0.6, 0.2, 0.2), 3), nrow=3, byrow = T), 3)
aic.mod(mod)
bic.mod(mod,500)
states<-viterbi(seal1$steplen[1:500],mod,3)
plot_viterbi(states,seal1$steplen[1:500],mod,3)
