{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE TemplateHaskell #-}

module MDP where

import Control.Applicative ((<$>))
import Control.Lens hiding (value)

import Data.Maybe
import Data.Map (Map)
import qualified Data.Map as Map

import Data.Foldable

import Text.Parsec
import Text.Parsec.String
import Text.Parsec.Extra (eol)
import Text.Parsec.Numbers


-- -------------------------------------------------------------------------------- --

type MDPKey = String
type MDPVal = String
data MDPEntry = MkMDPEntry {
      _eKey :: MDPKey
    , _eVal :: MDPVal
    } deriving Show

makeLenses ''MDPEntry

newEntry :: MDPKey -> MDPVal -> MDPEntry
newEntry = MkMDPEntry


-- data MDPData = MkMDPData {
--       _entries :: [MDPEntry]
--     , _keys :: Set MDPKey
--     } deriving Show

data MDPData = MkMDPData {
      _mdpData :: Map MDPKey MDPVal
    } deriving Show

makeLenses ''MDPData

emptyData :: MDPData
emptyData = MkMDPData Map.empty

addEntry :: MDPEntry -> MDPData -> MDPData
addEntry e d = d { _mdpData = Map.insert (view eKey e) (view eVal e) (view mdpData d) }

hasKey :: MDPKey -> MDPData -> Bool
hasKey k d = Map.member k (view mdpData d)

getKey :: MDPKey -> MDPData -> Maybe MDPVal
getKey k d = Map.lookup k (view mdpData d)

class ToMDP a where
    toMDP :: a -> String

instance ToMDP MDPEntry where
    toMDP e = view eKey e ++ " = " ++ view eVal e

instance ToMDP (Map MDPKey MDPVal) where
    toMDP = unlines . reverse . Map.foldlWithKey f []
        where f :: [String] -> MDPKey -> MDPVal -> [String]
              f acc k v = (k ++ " = " ++ v) : acc

instance ToMDP MDPData where
    toMDP = toMDP . view mdpData


-- -------------------------------------------------------------------------------- --



label' :: String -> Parser a -> Parser a
label' = flip label

name :: Parser String
name = label' "name" $ many1 $ alphaNum <|> oneOf "_-"

value :: Parser String
value = label' "value" $ anyChar `manyTill` (space' <|> tab' <|> comment' <|> eof')
    where space' = space >> return ()
          tab'  = tab >> return ()
          comment' = comment >> return ()
          eof' = try eof


floatStr :: Parser String
floatStr = label' "floatStr" $ do
             pref <- string "-" <|> return ""
             as <- many1 digit
             p <- char '.' <|> return '.'
             bs <- many1 digit <|> return "0"
             return $ pref ++ as ++ [p] ++ bs


whitespace :: Parser String
whitespace = label' "whitespace" $ many (oneOf " \t")

entity = label' "entity" $ do
           n <- name
           whitespace
           char '='
           whitespace
           v <- value
           return $ Just (n , v)

comment = label' "comment" $ do
            char ';'
            spaces
            anyChar `manyTill` try (eol <|> eof)

mdpParser :: Parser MDPData
mdpParser = do
  es <- map (uncurry newEntry) . catMaybes <$> many line
  return $ foldl' (flip addEntry) emptyData es


through :: Parser b -> a -> Parser a
through m v = m >> return v

(>~) :: Parser a -> Parser b -> Parser a
m >~ v = label' ">~" $ m >>= through v


line = do
  choice [ entity
         , space   >> return Nothing
         , comment >> return Nothing
         ]


testFloaStr = parseTest floatStr s
    where
      s = "0."

testValue = parseTest value s
    where
      s = "hbonds"

testEntity = parseTest entity s
    where
      -- s = "constraints     =  hbonds\n"
      -- s = "dt              =  0.002\n"
      s = "integrator      =  sd \n"

testComment = parseTest comment s
    where s = "; GBSA \n"

-- testMDP = parseTest mdpParser s
--     where s = unlines $ [ "constraints     =  hbonds"
--                         , "; GBSA "
--                         ]

test = do
  Right v <- readFile "/tmp/sim.mdp" >>= return . fmap toMDP . parse mdpParser ""
  putStr v


loadMDP :: FilePath -> IO (Either ParseError MDPData)
loadMDP p = readFile p >>= return . parse mdpParser "<mdpParser>"