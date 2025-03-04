"""
    update_istaNet!(B, resid, grad, X, Y, Z, norms, , reg, stepsize)

Updates coefficient estimates in place for each ISTA iteration based on the Elastic-net 
solution, when `X` and `Z` are both standardized. 

# Arguments 

- B = 2d array of floats consisting of coefficient estimates
- resid = 2d array of floats consisting of the residuals
- grad = 2d array of floats consisting of the gradient
- X = 2d array of floats consisting of the row covariates, with all 
  categorical variables coded in appropriate contrasts
- Y = 2d array of floats consisting of the multivariate response observations
- Z = 2d array of floats consisting of the column covariates, with all 
  categorical variables coded in appropriate contrasts
- norms = `nothing`
- lambdaL1 =  l1 penalty, a floating scalar
- lambdaL1 =  l2 penalty, a floating scalar
- reg = 2d array of bits, indicating whether or not to regularize each of the 
  coefficients
- stepsize = 1d array consisting of a float; step size of updates

# Value

None; updates coefficients in place

"""
function update_ista!(B::AbstractArray{Float64,2}, 
                      resid::AbstractArray{Float64,2}, 
                      grad::AbstractArray{Float64,2}, 
                      X::AbstractArray{Float64,2}, 
                      Y::AbstractArray{Float64,2}, 
                      Z::AbstractArray{Float64,2}, 
                      norms::Nothing, lambdaL1::Float64, lambdaL2::Float64, 
                      reg::BitArray{2}, 
                      stepsize::AbstractArray{Float64,1})
    
    # Update gradient
    calc_grad!(grad, X, Z, resid)
    
    # Cycle through all the coefficients to perform assignments
    for j = 1:size(B,2), i = 1:size(B,1)
        b2update = B[i,j] - stepsize[1] * grad[i,j] # RSS update
        b2sign = sign(b2update) # RSS update sign
        
        # Update the current coefficient 
        b = reg[i,j] ? prox(B[i,j], grad[i,j], b2sign, lambdaL1, norms, 
                            stepsize[1])/(1+2*lambdaL2*stepsize[1]) : b2update
        
        # Update coefficient estimate in the current copy
        if b != B[i,j] 
            B[i,j] = b 
        end 
    end 
    
    # Update residuals
    calc_resid!(resid, X, Y, Z, B) 
end


"""
    update_istaNet!(B, resid, grad, X, Y, Z, norms, , reg, stepsize)

Updates coefficient estimates in place for each ISTA iteration based on the Elastic-net
solution, when `X` and `Z` are not standardized. 

# Arguments 

- B = 2d array of floats consisting of coefficient estimates
- resid = 2d array of floats consisting of the residuals
- grad = 2d array of floats consisting of the gradient
- X = 2d array of floats consisting of the row covariates, with all 
  categorical variables coded in appropriate contrasts
- Y = 2d array of floats consisting of the multivariate response observations
- Z = 2d array of floats consisting of the column covariates, with all 
  categorical variables coded in appropriate contrasts
- norms = 2d array of floats consisting of the norms corresponding to each 
  coefficient
- lambdaL1 =  penalty, a floating scalar
- lambdaL2 =  penalty, a floating scalar
- reg = 2d array of bits, indicating whether or not to regularize each of the 
  coefficients
- stepsize = 1d array consisting of a float; step size of updates

# Value

None; updates coefficients in place

"""
function update_ista!(B::AbstractArray{Float64,2}, 
                      resid::AbstractArray{Float64,2}, 
                      grad::AbstractArray{Float64,2}, 
                      X::AbstractArray{Float64,2}, 
                      Y::AbstractArray{Float64,2}, 
                      Z::AbstractArray{Float64,2}, 
                      norms::AbstractArray{Float64,2}, 
                      lambdaL1::Float64, lambdaL2::Float64, reg::BitArray{2}, 
                      stepsize::AbstractArray{Float64,1}) 
    
    # Update gradient
    calc_grad!(grad, X, Z, resid) 

    # Cycle through all the coefficients to perform assignments
    for j = 1:size(B,2), i = 1:size(B,1)
        b2update = B[i,j] - stepsize[1] * grad[i,j]./norms[i,j] # L2 updates
        b2sign = sign(b2update) # L2 update signs
        
        # Update the current coefficient 
        b = reg[i,j] ? prox(B[i,j], grad[i,j], b2sign, lambdaL1, norms[i,j], 
                            stepsize[1])/(1+2*lambdaL2*stepsize[1]) : b2update
        
        # Update coefficient estimate in the current copy    
        if b != B[i,j] 
            B[i,j] = b 
        end 
    end 
    
    # Update residuals
    calc_resid!(resid, X, Y, Z, B)
end


"""
    istaNet!(X, Y, Z, lambda, alpha, B, regXidx, regZidx, reg, norms; 
          isVerbose, stepsize, thresh, maxiter)

Performs the Elastic-net version ISTA with fixed step size.

# Arguments

- X = 2d array of floats consisting of the row covariates, with all 
  categorical variables coded in appropriate contrasts
- Y = 2d array of floats consisting of the multivariate response
- Z = 2d array of floats consisting of the column covariates, with all 
  categorical variables coded in appropriate contrasts
- lambda = penalty parameter, a floating scalar
- alpha = parameter (ϵ[0, 1]) determining the mix of penalties between L1 and L2
- B = 2d array of floats consisting of starting coefficient estimates
- regXidx = 1d array of indices corresponding to regularized X covariates
- regZidx = 1d array of indices corresponding to regularized Z covariates
- reg = 2d array of bits, indicating whether or not to regularize each of the 
  coefficients
- norms = 2d array of floats consisting of the norms corresponding to each 
  coefficient or `nothing`

# Keyword arguments

- isVerbose = boolean flag indicating whether or not to print messages.  
  Defaults to `true`. 
- stepsize = float; step size for updates. Defaults to `0.01`. 
- thresh = threshold at which the coefficients are considered to have 
  converged, a floating scalar. Defaults to `10^(-7)`. 
- maxiter = maximum number of update iterations. Defaults to `10^10`. 

# Value

None; updates coefficients in place

# Some notes

Convergence is determined as when the log ratio of the current and previous 
criteria is less than the threshold `thresh`. 

The default method for choosing the fixed step size for `ista!` is to use the 
reciprocal of the product of the maximum eigenvalues of `X*transpose(X)` 
and `Z*transpose(Z)`. This is computed by the `mlmnet` function when `ista!` 
is passed into the `fun` argument and `setStepSize` is set to `true`. If 
`setStepSize` is set to `false`, the value of the `stepsize` argument will be 
used as the fixed step size. Note that obtaining the eigenvalues when `X` 
and/or `Z` are very large may exceed computational limitations. 

"""
function ista!(X::AbstractArray{Float64,2}, Y::AbstractArray{Float64,2}, 
               Z::AbstractArray{Float64,2}, lambda::Float64, alpha::Float64, 
               B::AbstractArray{Float64,2}, 
               regXidx::AbstractArray{Int64,1}, 
               regZidx::AbstractArray{Int64,1}, reg::BitArray{2}, norms; 
               isVerbose::Bool=true, stepsize::Float64=0.01, 
               thresh::Float64=10.0^(-7), maxiter::Int=10^10)

    # Re-parametrize the Elastic-net tuning parameters
    lambdaL1 = lambda*alpha
    lambdaL2 = lambda*(1-alpha)

    # Pre-allocating arrays to store residuals using and gradient. 
    resid = Array{Float64}(undef, size(Y)) 
    grad = Array{Float64}(undef, size(B))
    
    # Calculate residuals 
    calc_resid!(resid, X, Y, Z, B) 
    
    # Denominators of criterion
    crit_denom = [size(X,1)*size(Z,1), size(X,2)*size(Z,2)] 
    # Placeholder to store the old criterion 
    oldcrit = 1.0 
    # Calculate the current criterion (loss function with Elastic-net penalty)
    crit = criterion(B[regXidx, regZidx], resid, lambdaL1, lambdaL2, crit_denom) 
    
    stepsize = [stepsize]
    iter = 0
    # Iterate until coefficients converge or maximum iterations have been 
    # reached.
    while (abs(log(crit/oldcrit)) > thresh) && (iter < maxiter)
        # Store the current criterion
        oldcrit = crit 
        # Update the coefficient estimates
        update_ista!(B, resid, grad, X, Y, Z, norms, lambdaL1, lambdaL2, reg, stepsize) 
        # Calculate the criterion after updating
        crit = criterion(B[regXidx, regZidx], resid, lambdaL1, lambdaL2, crit_denom) 
        
        iter += 1 # Increment the number of iterations
        # Warning message if coefficient estimates do not converge.
        if iter==(maxiter) 
            println("Estimates did not converge.")
        end
    end

    println_verbose(string("Criterion: ", crit), isVerbose)
    println_verbose(string("Number of iterations: ", iter), isVerbose)
end