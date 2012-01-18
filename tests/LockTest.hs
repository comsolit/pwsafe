module LockTest (test) where
import           Test.Framework
import           Test.Framework.Providers.QuickCheck2
import           Test.QuickCheck
import           Test.QuickCheck.Monadic

import           Control.Monad (when)
import           Control.Exception (finally)

import qualified Lock

test :: Test
test = testProperty "acquireRelease" prop_acquireRelease

-- | Make sure that lock is not currently held, run action, release lock
--
-- Every test should be wrapped with this!
lockTest :: IO a -> IO a
lockTest action = do
  r <- Lock.acquire
  when (not r) $ fail "The lock is currently held! Are you accessing the resource right now?"
  True <- Lock.release
  action `finally` Lock.release

data Action = Acquire | Release
  deriving (Eq, Show)

instance Arbitrary Action where
  arbitrary = (\x -> if x then Acquire else Release) `fmap` arbitrary

prop_acquireRelease :: [Action] -> Property
prop_acquireRelease actions = monadicIO $ do
  result <- run $ lockTest $ mapM runAction actions
  assert $ result == map snd (deduceResult actions)
  return ()
  where
    runAction Acquire = Lock.acquire
    runAction Release = Lock.release

    deduceResult :: [Action] -> [(Action, Bool)]
    deduceResult = reverse . foldr step [] . reverse
      where
        step currentAction []                          = [(currentAction, currentAction == Acquire)]
        step currentAction l@((previousAction, _) : _) =  (currentAction, currentAction /= previousAction ) : l
