module Heist.Interpreted.Splices.Apply where

------------------------------------------------------------------------------
import           Data.Maybe
import           Data.Text (Text)
import qualified Data.Text.Encoding as T
import qualified Text.XmlHtml as X

------------------------------------------------------------------------------
import           Heist.Common
import           Heist.Interpreted.Internal
import           Heist.Types

------------------------------------------------------------------------------
-- | Default name for the apply splice.
applyTag :: Text
applyTag = "apply"


------------------------------------------------------------------------------
-- | Default attribute name for the apply tag.
applyAttr :: Text
applyAttr = "template"


------------------------------------------------------------------------------
-- | Raw core of apply functionality.  This is abstracted for use in other
-- places like an enhanced (from the original) bind
rawApply :: (Monad n)
         => [X.Node]
         -> TPath
         -> [X.Node]
         -> Splice n
rawApply calledNodes newContext paramNodes = do
    st <- getTS  -- Can't use localTS here because the modifier is not pure
    processedParams <- runNodeList paramNodes
    modifyTS (bindSplice "content" (return processedParams) .
              setCurContext newContext)

    if _recursionDepth st < mAX_RECURSION_DEPTH
        then do modRecursionDepth (+1)
                result <- runNodeList calledNodes
                restoreTS st
                return result
        else return [] -- Need to crap out hard here if running at load time



------------------------------------------------------------------------------
-- | Applies a template as if the supplied nodes were the children of the
-- <apply> tag.
applyNodes :: Monad n => Template -> Text -> Splice n
applyNodes nodes template = do
    st <- getTS
    maybe (return []) -- TODO: error handling
          (\(t,ctx) -> do
              addDoctype $ maybeToList $ X.docType $ dfDoc t
              rawApply (X.docContent $ dfDoc t) ctx nodes)
          (lookupTemplate (T.encodeUtf8 template) st _templateMap)


------------------------------------------------------------------------------
-- | Implementation of the apply splice.
applyImpl :: Monad n => Splice n
applyImpl = do
    node <- getParamNode
    case X.getAttribute applyAttr node of
        Nothing   -> return [] -- TODO: error handling
        Just template -> applyNodes (X.childNodes node) template


