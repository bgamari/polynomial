{-# LANGUAGE ParallelListComp #-}
module Math.Polynomial.Interpolation where

import Math.Polynomial
import Math.Polynomial.Lagrange
import Data.List

-- |Evaluate a polynomial passing through the specified set of points.  The
-- order of the interpolating polynomial will (at most) be one less than
-- the number of points given.
polyInterp :: Fractional a => [(a,a)] -> a -> a
polyInterp xys = head . last . neville xys

-- |Computes the tableau generated by Neville's algorithm.  Each successive
-- row of the table is a list of interpolants one order higher than the previous,
-- using a range of input points starting at the same position in the input
-- list as the interpolant's position in the output list.
neville :: Fractional a => [(a,a)] -> a -> [[a]]
neville xys x = table
    where
        (xs,ys) = unzip xys
        table = ys :
            [ [ ((x - x_j) * p1 + (x_i - x) * p0) / (x_i - x_j)
              | p0:p1:_ <- tails row
              | x_j     <- xs
              | x_i     <- x_is
              ]
            | row  <- table
            | x_is <- tail (tails xs)
            , not (null x_is)
            ]

-- |Computes the tableau generated by a modified form of Neville's algorithm
-- described in Numerical Recipes, Ch. 3, Sec. 2, which records the differences
-- between interpolants at each level.  Each pair (c,d) is the amount to add
-- to the previous level's interpolant at either the same or the subsequent
-- position (respectively) in order to obtain the new level's interpolant.
-- Mathematically, either sum yields the same value, but due to numerical
-- errors they may differ slightly, and some \"paths\" through the table
-- may yield more accurate final results than others.
nevilleDiffs :: Fractional a => [(a,a)] -> a -> [[(a,a)]]
nevilleDiffs xys x = table
    where
        (xs,ys) = unzip xys
        table = zip ys ys :
            [ [ ( {-c-} (x_j - x) * (c1 - d0) / (x_j - x_i)
                , {-d-} (x_i - x) * (c1 - d0) / (x_j - x_i)
                )
              | (_c0,d0):(c1,_d1):_ <- tails row
              | x_j     <- xs
              | x_i     <- x_is
              ]
            | row  <- table
            | x_is <- tail (tails xs)
            , not (null x_is)
            ]

-- |Fit a polynomial to a set of points by iteratively evaluating the
-- interpolated polynomial (using 'polyInterp') at 0 to establish the
-- constant coefficient and reducing the polynomial by subtracting that
-- coefficient from all y's and dividing by their corresponding x's.
--
-- Slower than 'lagrangePolyFit' but stable under different sets of
-- conditions.
--
-- Note that computing the coefficients of a fitting polynomial is an
-- inherently ill-conditioned problem.  In most cases it is both faster and
-- more accurate to use 'polyInterp' or 'nevilleDiffs' instead of evaluating
-- a fitted polynomial.
iterativePolyFit :: (Fractional a, Eq a) => [(a,a)] -> Poly a
iterativePolyFit = poly LE . loop
    where
        loop  [] = []
        loop xys = c0 : loop (drop 1 xys')
            where
                c0   = polyInterp xys 0
                xys' =
                    [ (x,(y - c0) / x)
                    | (x,y) <- xys
                    ]

-- |Fit a polynomial to a set of points using barycentric Lagrange polynomials.
--
-- Note that computing the coefficients of a fitting polynomial is an
-- inherently ill-conditioned problem.  In most cases it is both faster and
-- more accurate to use 'polyInterp' or 'nevilleDiffs' instead of evaluating
-- a fitted polynomial.
lagrangePolyFit :: (Fractional a, Eq a) => [(a,a)] -> Poly a
lagrangePolyFit xys = sumPolys
    [ scalePoly f (fst (contractPoly p x))
    | f <- zipWith (/) ys phis
    | x <- xs
    ]
    where
        (xs,ys) = unzip xys
        p = lagrange xs
        phis = map (snd . evalPolyDeriv p) xs
