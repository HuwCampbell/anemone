{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE ForeignFunctionInterface #-}
module Anemone.Foreign.Pack (
    Packed64(..)
  , pack64
  , unpack64

  , bitsof
  ) where

import           Data.Bits ((.|.))
import           Data.ByteString.Internal (ByteString(..))
import qualified Data.ByteString.Internal as B
import qualified Data.Vector.Storable as Storable
import           Data.Word (Word8, Word64)

import           Foreign.ForeignPtr (withForeignPtr)
import           Foreign.Ptr

import           GHC.ForeignPtr (mallocPlainForeignPtrBytes)

import           P

import           System.IO (IO)
import           System.IO.Unsafe (unsafePerformIO)


data Packed64
 = Packed64
 { packedBlocks :: !Int
 , packedBits   :: !Int
 , packedBytes  :: !ByteString
 } deriving (Eq, Ord, Read, Show)

-- | Packs 64n x 64-bit words, returns Nothing if the length of the input
--   vector was not a multiple of 64.
pack64 :: Storable.Vector Word64 -> Maybe Packed64
pack64 xs
 | remains /= 0
 = Nothing

 | otherwise
 = Just . Packed64 blocks bits . unsafePerformIO .
    withForeignPtr fp $ \pin ->
    B.create outputSize $ \pout ->
     c_pack64_64
      (fromIntegral blocks)
      (fromIntegral bits)
      pin
      pout

 where
  (fp, _)
   = Storable.unsafeToForeignPtr0 xs

  (blocks, remains)
   = Storable.length xs `divMod` 64

  bits
   = bitsof $ Storable.foldl' (.|.) 0 xs

  outputSize
   = fromIntegral $ (bits * blocks * 64) `div` 8

-- | Unpacks 64n x 64-bit words.
unpack64 :: Packed64 -> Maybe (Storable.Vector Word64)
unpack64 (Packed64 blocks bits (PS fpin off len))
 | len /= inputSize
 = Nothing

 | otherwise
 = unsafePerformIO $ do
    fpout <- mallocPlainForeignPtrBytes outputSize

    withForeignPtr fpout $ \pout ->
     withForeignPtr fpin $ \pin -> do
      c_unpack64_64
       (fromIntegral blocks)
       (fromIntegral bits)
       (pin `plusPtr` off)
       pout

    return . Just $
     Storable.unsafeFromForeignPtr0 fpout outputCount
 where
   inputSize
    = (bits * blocks * 64) `div` 8

   outputSize
    = outputCount * 8

   outputCount
    = blocks * 64

-- | Gets the number of bits required to store a value.
bitsof :: Word64 -> Int
bitsof
 = fromIntegral . c_bitsof

-- | void pack64_64 (uint64_t blocks, const uint64_t bits, const uint64_t *in, uint8_t *out)
foreign import ccall unsafe "anemone_pack64_64"
  c_pack64_64 :: Word64 -> Word64 -> Ptr Word64 -> Ptr Word8 -> IO ()

-- | void anemone_unpack64_64 (uint64_t blocks, const uint64_t bits, const uint8_t *in, uint64_t *out)
foreign import ccall unsafe "anemone_unpack64_64"
  c_unpack64_64 :: Word64 -> Word64 -> Ptr Word8 -> Ptr Word64 -> IO ()

-- | uint64_t anemone_bitsof (uint64_t value)
foreign import ccall unsafe "anemone_bitsof"
  c_bitsof :: Word64 -> Word64
