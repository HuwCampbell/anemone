{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ForeignFunctionInterface #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# OPTIONS_GHC -fno-warn-missing-signatures #-}

module Test.Anemone.Foreign.Mempool where

import Anemone.Foreign.Data
import qualified Anemone.Foreign.Mempool as Mempool

import            P
import            Disorder.Core
import            Disorder.Core.IO
import            Test.QuickCheck
import            Test.QuickCheck.Instances()

import qualified  Data.List as List

foreign import ccall unsafe
    test_mempool_free
    :: CInt -> CInt -> CSize -> CBool

prop_mempool_free :: Property
prop_mempool_free
 = forAll iterations $ \a ->
   forAll iterations $ \b ->
   forAll megabytes $ \c ->
   test_mempool_free a b c /= 0

foreign import ccall unsafe
    test_mempool_nonoverlap
    :: CInt -> CSize -> CBool

prop_mempool_nonoverlap :: Property
prop_mempool_nonoverlap
 = forAll iterations $ \a ->
   forAll megabytes $ \b ->
   test_mempool_nonoverlap a b /= 0

-- Really simple sanity test of the FFI
-- Create a pool, allocate a whole bunch of pointers and make sure the pointers are distinct
prop_mempool_sanity :: Property
prop_mempool_sanity
 = forAll (listOf megabytes) $ \sizes ->
   testIO $ do
    pool <- Mempool.create
    vals <- mapM (Mempool.allocBytes pool) sizes
    Mempool.free pool
    -- If all pointers are distinct, length of uniques should be same as original length
    let uniqs = List.nub vals
    return (counterexample (show vals) $ length vals === length uniqs)

iterations :: Gen CInt
iterations = choose (1, 100)

-- Choose some number of bytes from 1 to 2mb
-- (2mb is larger than block size)
megabytes :: Gen CSize
megabytes = choose (0, 2 * 1024 * 1024)

return []
tests = $disorderCheckEnvAll TestRunNormal

