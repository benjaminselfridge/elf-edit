{-
Module           : Data.ElfEdit.Sections
Copyright        : (c) Galois, Inc 2016-2018

Defines sections and related types.
-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE PatternGuards #-}
{-# LANGUAGE PatternSynonyms #-}
module Data.ElfEdit.Sections
  ( -- * Sections
    ElfSection(..)
  , elfSectionFileSize
    -- ** ElfSectionIndex
  , ElfSectionIndex(..)
  , pattern SHN_UNDEF
  , pattern SHN_ABS
  , pattern SHN_COMMON
  , pattern SHN_LORESERVE
  , pattern SHN_LOPROC
  , pattern SHN_X86_64_LCOMMON
  , pattern SHN_IA_64_ANSI_COMMON
  , pattern SHN_MIPS_SCOMMON
  , pattern SHN_MIPS_SUNDEFINED
  , pattern SHN_TIC6X_SCOMMON
  , pattern SHN_HIPROC
  , pattern SHN_LOOS
  , pattern SHN_HIOS
  , ppElfSectionIndex
    -- ** Elf section type
  , ElfSectionType(..)
  , pattern SHT_NULL
  , pattern SHT_PROGBITS
  , pattern SHT_SYMTAB
  , pattern SHT_STRTAB
  , pattern SHT_RELA
  , pattern SHT_HASH
  , pattern SHT_DYNAMIC
  , pattern SHT_NOTE
  , pattern SHT_NOBITS
  , pattern SHT_REL
  , pattern SHT_SHLIB
  , pattern SHT_DYNSYM
    -- ** Elf section flags
  , ElfSectionFlags(..)
  , shf_none
  , shf_write
  , shf_alloc
  , shf_execinstr
  , shf_merge
  , shf_tls
  ) where

import           Data.Bits
import qualified Data.ByteString as B
import qualified Data.Vector as V
import           Data.Word
import           Numeric (showHex)

import           Data.ElfEdit.Enums
import           Data.ElfEdit.Utils (showFlags)

------------------------------------------------------------------------
-- ElfSectionIndex

-- | Identifier to identify sections
newtype ElfSectionIndex = ElfSectionIndex { fromElfSectionIndex :: Word16 }
  deriving (Eq, Ord, Enum, Num, Real, Integral)

-- | Undefined section
pattern SHN_UNDEF :: ElfSectionIndex
pattern SHN_UNDEF = ElfSectionIndex 0

-- | Associated symbol is absolute.
pattern SHN_ABS :: ElfSectionIndex
pattern SHN_ABS = ElfSectionIndex 0xfff1

-- | This identifies a symbol in a relocatable file that is not yet allocated.
--
-- The linker should allocate space for this symbol at an address that is a
-- aligned to the symbol value ('steValue').
pattern SHN_COMMON :: ElfSectionIndex
pattern SHN_COMMON = ElfSectionIndex 0xfff2

-- | Start of reserved indices.
pattern SHN_LORESERVE :: ElfSectionIndex
pattern SHN_LORESERVE = ElfSectionIndex 0xff00

-- | Start of processor specific.
pattern SHN_LOPROC :: ElfSectionIndex
pattern SHN_LOPROC = SHN_LORESERVE

-- | Like SHN_COMMON but symbol in .lbss
pattern SHN_X86_64_LCOMMON :: ElfSectionIndex
pattern SHN_X86_64_LCOMMON = ElfSectionIndex 0xff02

-- | Only used by HP-UX, because HP linker gives
-- weak symbols precdence over regular common symbols.
pattern SHN_IA_64_ANSI_COMMON :: ElfSectionIndex
pattern SHN_IA_64_ANSI_COMMON = SHN_LORESERVE

-- | Small common symbols
pattern SHN_MIPS_SCOMMON :: ElfSectionIndex
pattern SHN_MIPS_SCOMMON = ElfSectionIndex 0xff03

-- | Small undefined symbols
pattern SHN_MIPS_SUNDEFINED :: ElfSectionIndex
pattern SHN_MIPS_SUNDEFINED = ElfSectionIndex 0xff04

-- | Small data area common symbol.
pattern SHN_TIC6X_SCOMMON :: ElfSectionIndex
pattern SHN_TIC6X_SCOMMON = SHN_LORESERVE

-- | End of processor specific.
pattern SHN_HIPROC :: ElfSectionIndex
pattern SHN_HIPROC = ElfSectionIndex 0xff1f

-- | Start of OS-specific.
pattern SHN_LOOS :: ElfSectionIndex
pattern SHN_LOOS = ElfSectionIndex 0xff20

-- | End of OS-specific.
pattern SHN_HIOS :: ElfSectionIndex
pattern SHN_HIOS = ElfSectionIndex 0xff3f

instance Show ElfSectionIndex where
  show i = ppElfSectionIndex EM_NONE ELFOSABI_SYSV maxBound "SHN_" i

-- | Pretty print an elf section index
ppElfSectionIndex :: ElfMachine
                  -> ElfOSABI
                  -> Word16 -- ^ Number of sections.
                  -> String -- ^ Prefix for names
                  -> ElfSectionIndex
                  -> String
ppElfSectionIndex m abi this_shnum pre tp =
  case tp of
    SHN_UNDEF -> pre ++ "UND"
    SHN_ABS   -> pre ++ "ABS"
    SHN_COMMON -> pre ++ "COM"
    SHN_IA_64_ANSI_COMMON | m == EM_IA_64, abi == ELFOSABI_HPUX     -> pre ++ "ANSI_COM"
    SHN_X86_64_LCOMMON    | m `elem` [ EM_X86_64, EM_L1OM, EM_K1OM] -> pre ++ "LARGE_COM"
    SHN_MIPS_SCOMMON      | m == EM_MIPS                            -> pre ++ "SCOM"
    SHN_MIPS_SUNDEFINED   | m == EM_MIPS                            -> pre ++ "SUND"
    SHN_TIC6X_SCOMMON     | m == EM_TI_C6000                        -> pre ++ "SCOM"

    ElfSectionIndex w
      | tp >= SHN_LOPROC, tp <= SHN_HIPROC   -> pre ++ "PRC[0x" ++ showHex w "]"
      | tp >= SHN_LOOS,   tp <= SHN_HIOS     -> pre ++ "OS [0x" ++ showHex w "]"
      | tp >= SHN_LORESERVE                  -> pre ++ "RSV[0x" ++ showHex w "]"
      | w >= this_shnum                      -> "bad section index[" ++ show w ++ "]"
      | otherwise                            -> show w

------------------------------------------------------------------------
-- ElfSectionType

-- | The type associated with an Elf file.
newtype ElfSectionType = ElfSectionType { fromElfSectionType :: Word32 }
  deriving (Eq, Ord)

-- | Identifies an empty section header.
pattern SHT_NULL :: ElfSectionType
pattern SHT_NULL     = ElfSectionType  0
-- | Contains information defined by the program
pattern SHT_PROGBITS :: ElfSectionType
pattern SHT_PROGBITS = ElfSectionType  1
-- | Contains a linker symbol table
pattern SHT_SYMTAB :: ElfSectionType
pattern SHT_SYMTAB   = ElfSectionType  2
-- | Contains a string table
pattern SHT_STRTAB :: ElfSectionType
pattern SHT_STRTAB   = ElfSectionType  3
-- | Contains "Rela" type relocation entries
pattern SHT_RELA :: ElfSectionType
pattern SHT_RELA     = ElfSectionType  4
-- | Contains a symbol hash table
pattern SHT_HASH :: ElfSectionType
pattern SHT_HASH     = ElfSectionType  5
-- | Contains dynamic linking tables
pattern SHT_DYNAMIC :: ElfSectionType
pattern SHT_DYNAMIC  = ElfSectionType  6
-- | Contains note information
pattern SHT_NOTE :: ElfSectionType
pattern SHT_NOTE     = ElfSectionType  7
-- | Contains uninitialized space; does not occupy any space in the file
pattern SHT_NOBITS :: ElfSectionType
pattern SHT_NOBITS   = ElfSectionType  8
-- | Contains "Rel" type relocation entries
pattern SHT_REL :: ElfSectionType
pattern SHT_REL = ElfSectionType  9
-- | Reserved
pattern SHT_SHLIB :: ElfSectionType
pattern SHT_SHLIB = ElfSectionType 10
-- | Contains a dynamic loader symbol table
pattern SHT_DYNSYM :: ElfSectionType
pattern SHT_DYNSYM   = ElfSectionType 11

instance Show ElfSectionType where
  show tp =
    case tp of
      SHT_NULL     -> "SHT_NULL"
      SHT_PROGBITS -> "SHT_PROGBITS"
      SHT_SYMTAB   -> "SHT_SYMTAB"
      SHT_STRTAB   -> "SHT_STRTAB"
      SHT_RELA     -> "SHT_RELA"
      SHT_HASH     -> "SHT_HASH"
      SHT_DYNAMIC  -> "SHT_DYNAMIC"
      SHT_NOTE     -> "SHT_NOTE"
      SHT_NOBITS   -> "SHT_NOBITS"
      SHT_REL      -> "SHT_REL"
      SHT_SHLIB    -> "SHT_SHLIB"
      SHT_DYNSYM   -> "SHT_DYNSYM"
      ElfSectionType w -> "(Unknown type " ++ show w ++ ")"

------------------------------------------------------------------------
-- ElfSectionFlags

-- | Flags for sections
newtype ElfSectionFlags w = ElfSectionFlags { fromElfSectionFlags :: w }
  deriving (Eq, Bits)

instance (Bits w, Integral w, Show w) => Show (ElfSectionFlags w) where
  showsPrec d (ElfSectionFlags w) = showFlags "shf_none" names d w
    where names = V.fromList ["shf_write", "shf_alloc", "shf_execinstr", "8", "shf_merge"]

-- | Empty set of flags
shf_none :: Num w => ElfSectionFlags w
shf_none = ElfSectionFlags 0x0

-- | Section contains writable data
shf_write :: Num w => ElfSectionFlags w
shf_write = ElfSectionFlags 0x1

-- | Section is allocated in memory image of program
shf_alloc :: Num w => ElfSectionFlags w
shf_alloc = ElfSectionFlags 0x2

-- | Section contains executable instructions
shf_execinstr :: Num w => ElfSectionFlags w
shf_execinstr = ElfSectionFlags 0x4

-- | The contents of this section can be merged with elements in
-- sections of the same name, type, and flags.
shf_merge :: Num w => ElfSectionFlags w
shf_merge = ElfSectionFlags 0x10

-- | Section contains TLS data (".tdata" or ".tbss")
--
-- Information in it may be modified by the dynamic linker, but is only copied
-- once the binary is linked.
shf_tls :: Num w => ElfSectionFlags w
shf_tls = ElfSectionFlags 0x400

------------------------------------------------------------------------
-- ElfSection

-- | A section in the Elf file.
data ElfSection w = ElfSection
    { elfSectionIndex     :: !Word16
      -- ^ Unique index to identify section.
    , elfSectionName      :: !B.ByteString
      -- ^ Name of the section.
    , elfSectionType      :: !ElfSectionType
      -- ^ Type of the section.
    , elfSectionFlags     :: !(ElfSectionFlags w)
      -- ^ Attributes of the section.
    , elfSectionAddr      :: !w
      -- ^ The virtual address of the beginning of the section in memory.
      --
      -- This should be 0 for sections that are not loaded into target memory.
    , elfSectionSize      :: !w
      -- ^ The size of the section. Except for SHT_NOBITS sections, this is the
      -- size of elfSectionData.
    , elfSectionLink      :: !Word32
      -- ^ Contains a section index of an associated section, depending on section type.
    , elfSectionInfo      :: !Word32
      -- ^ Contains extra information for the index, depending on type.
    , elfSectionAddrAlign :: !w
      -- ^ Contains the required alignment of the section.  This should be a power of
      -- two, and the address of the section should be a multiple of the alignment.
      --
      -- Note that when writing files, no effort is made to add padding so that the
      -- alignment constraint is correct.  It is up to the user to insert raw data segments
      -- as needed for padding.  We considered inserting padding automatically, but this
      -- can result in extra bytes inadvertently appearing in loadable segments, thus
      -- breaking layout constraints.  In particular, 'ld' sometimes generates files where
      -- the '.bss' section address is not a multiple of the alignment.
    , elfSectionEntSize   :: !w
      -- ^ Size of entries if section has a table.
    , elfSectionData      :: !B.ByteString
      -- ^ Data in section.
    } deriving (Eq, Show)

-- | Returns number of bytes in file used by section.
elfSectionFileSize :: Integral w => ElfSection w -> w
elfSectionFileSize = fromIntegral . B.length . elfSectionData
