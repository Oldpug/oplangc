module Language.OpLang.Codegen.C(compile) where

import Control.Monad(unless)
import Data.Char(ord)
import Data.Foldable(fold)
import qualified Data.Map.Strict as M
import Data.Text(Text)
import qualified Data.Text as T
import qualified Data.Text.IO as T.IO
import Numeric(showHex)
import System.Directory(removeFile)
import System.FilePath(dropExtension)
import System.Process(system)
import Text.Builder(Builder)
import qualified Text.Builder as B

import Language.OpLang.IR(Op(..), Name, Body, Defs)
import Opts(Opts(..))

type CCode = Builder

showC :: Show a => a -> CCode
showC = B.string . show

cName :: Name -> CCode
cName = maybe "main" \n -> "o" <> B.string (showHex (ord n) "")

programPrologue :: Word -> Word -> CCode
programPrologue stackSize tapeSize =
  "#include<stdio.h>\n#include<string.h>\n#define S "
  <> showC stackSize
  <> "\n#define T "
  <> showC tapeSize
  <> "\nchar s_[S],*s=s_;"

compileProto :: Name -> CCode
compileProto name = "void " <> cName name <> "();"

compileDef :: Name -> Body -> CCode
compileDef name body = "void " <> cName name <> "(){char t_[T],*t;l:t=t_;memset(t,0,T);" <> compileOps name body <> "}"

compileMain :: Body -> CCode
compileMain body = "int main(){char t_[T],*t=t_;memset(t,0,T);" <> compileOps Nothing body <> "return 0;}"

compileOps :: Name -> [Op] -> CCode
compileOps name ops = mconcat $ compileOp name "t" <$> ops

sign :: (Ord a, Num a) => a -> CCode
sign n
  | n < 0 = "-"
  | otherwise = "+"

repeatText :: Word -> Text -> CCode
repeatText n = B.text . T.concat . replicate (fromIntegral n)

compileOp :: Name -> CCode -> Op -> CCode
compileOp name tape = \case
  Add n -> "*" <> tape <> sign n <> "=" <> showC (abs n) <> ";"
  Move n -> tape <> sign n <> "=" <> showC (abs n) <> ";"
  Set n -> "*" <> tape <> "=" <> showC n <> ";"
  Pop n -> "*" <> tape <> "=*(s-=" <> showC n <> ");"
  Push -> "*(s++)=*" <> tape <> ";"
  Peek -> "*" <> tape <> "=*(s-1);"
  WithOffset off op -> compileOp name ("(" <> tape <> "+" <> showC off <> ")") op
  Loop ops -> "while(*t){" <> compileOps name ops <> "}"
  Read -> "scanf(\"%c\"," <> tape <> ");"
  Write 1 -> "printf(\"%c\",*" <> tape <> ");"
  Write n -> "{char c=*" <> tape <> ";printf(\"" <> repeatText n "%c" <> "\"" <> repeatText n ",c" <> ");}"
  OpCall c -> cName c <> "();"
  TailCall -> "goto l;"

codegen :: Word -> Word -> Defs -> Text
codegen stackSize tapeSize defs =
  B.run
  $ programPrologue stackSize tapeSize
  <> fold (compileProto <$> M.keys defs')
  <> fold (M.mapWithKey compileDef defs')
  <> compileMain (defs M.! Nothing)
    where
      defs' = M.delete Nothing defs

cFile :: String -> String
cFile file = dropExtension file <> ".c"

quote :: String -> String
quote s = '"' : (s <> "\"")

compile :: Opts -> Defs -> IO ()
compile Opts{..} d = do
  let cPath = cFile optsPath
  let code = codegen optsStackSize optsTapeSize d

  T.IO.writeFile cPath code
  system $ quote optsCCPath <> " -o " <> quote optsOutPath <> " " <> quote cPath

  unless optsKeepCFile $
    removeFile cPath
