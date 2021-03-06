module Opts(Opts(..), getOpts) where

import Options.Applicative

data Opts =
  Opts
  { optsOptPasses :: Word
  , optsStackSize :: Word
  , optsTapeSize :: Word
  , optsKeepCFile :: Bool
  , optsCCPath :: String
  , optsOutPath :: String
  , optsPath :: String
  }

defaultOptPasses :: Word
defaultOptPasses = 64

defaultStackSize :: Word
defaultStackSize = 4096

defaultTapeSize :: Word
defaultTapeSize = 65536

defaultCCPath :: String
defaultCCPath = "cc"

defaultOutPath :: String
defaultOutPath = ""

optsParser :: ParserInfo Opts
optsParser =
  info
    (infoOption "oplang v0.1.0.0" (short 'v' <> long "version" <> help "Shows version information.")
      <*> helper
      <*> programOptions)
    (fullDesc
      <> progDesc "Compiles an OpLang source file to a native executable."
      <> header "oplang - The OpLang Compiler")

  where
    programOptions :: Parser Opts
    programOptions =
      Opts
        <$> option auto (short 'O' <> long "opt-passes" <> metavar "PASSES" <> value defaultOptPasses <> help "Specify the number of optimization passes to perform.")
        <*> option auto (short 'S' <> long "stack-size" <> metavar "STACK" <> value defaultStackSize <> help "Specify the size of the stack.")
        <*> option auto (short 'T' <> long "tape-size" <> metavar "TAPE" <> value defaultTapeSize <> help "Specify the size of the memory tape.")
        <*> switch (short 'K' <> long "keep-c-file" <> help "Specifiy whether to keep the resulting C file.")
        <*> strOption (short 'C' <> long "cc-path" <> metavar "CC_PATH" <> value defaultCCPath <> help "Specify the path of the C compiler to use.")
        <*> strOption (short 'o' <> long "out-path" <> metavar "OUT_PATH" <> value defaultOutPath <> help "Specify the path of the resulting executable.")
        <*> strArgument (metavar "PATH" <> help "The source file to compile.")

getOpts :: IO Opts
getOpts = execParser optsParser
