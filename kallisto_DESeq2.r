#!/usr/bin/env Rscript
################################################################################
### R script to compare two different conditions with kallisto and DESeq2 packages
### Aditya Narayan Sarangi
### Designed to be executed with bulkRNASeqPIPE
################################################################################

rm(list=ls())                                        # remove all the objects from the R session
suppressMessages(library(rnaseqdea))
suppressMessages(library(DESeq2))
suppressMessages(library(DT))
suppressMessages(library(ggplot2))
suppressMessages(library(gplots))
suppressMessages(library(EnhancedVolcano))
suppressMessages(library(GenomicFeatures))
suppressMessages(library(regionReport))
suppressMessages(library(DEFormats))
suppressMessages(library(RColorBrewer))
suppressMessages(library(pheatmap))
suppressMessages(library(dplyr))
suppressMessages(library(colorspace))
suppressMessages(library(optparse))
suppressMessages(library(scales))
suppressMessages(library(readr)) 
suppressMessages(library(rhdf5))
suppressMessages(library(tximport))


# to run the script in command lines

# options list with associated default value.
option_list <- list( 
make_option(c("-P", "--projectName"),
			default=basename(getwd()),
			dest="projectName",
			help="name of the project used for storing images and tables [default: name of the current directory]."),

make_option(c("-R", "--reportName"),
			default="Kallisto_DESeq2_HTML_Report",
			dest="reportName",
			help="name of the project used for the report [default: name of the current directory]."),


make_option(c("-t", "--targetFile"),
			default="target.txt",
			dest="targetFile",
			help="path to the design/target file [default: %default]."),

make_option(c("-T", "--templateFile"),
			dest="templateFile",
			help="path to the R markdown Template file"),

make_option(c("-G", "--tx2geneDirectory"),
			dest="tx2geneDirectory",
			help="path to the tx2gene Directory."),

make_option(c("-q", "--quantDir"),
			dest="quantDir",
			help="path to the directory containing the Kallisto Quantification files"),

	
make_option(c("-v", "--varInt"),
			default="group",
			dest="varInt", 
			help="factor of interest [default: %default]"),

make_option(c("-c", "--condRef"),
			default="WT",
			dest="condRef",
			help="reference biological condition [default: %default]"),

make_option(c("-b", "--batch"),
			default=NULL,
			dest="batch",
			help="blocking factor [default: %default] or \"batch\" for example"),

make_option(c("-f", "--fitType"),
			default="parametric",
			dest="fitType", 
			help="mean-variance relationship: [default: %default],local or mean"),

make_option(c("-a", "--alpha"),
			default=0.05,
			dest="alpha", 
			help="threshold of statistical significance [default: %default]"),

make_option(c("-p", "--pAdjustMethod"),
			default="BH",
			dest="pAdjustMethod", 
			help="p-value adjustment method: \"BH\" or \"BY\" [default: %default]"),


make_option(c("-l", "--locfunc"),
			default="median",
			dest="locfunc", 
			help="median or shorth to estimate the size factors [default: %default]")

)

# now parse the command line to check which option is given and get associated values
parser <- OptionParser(usage="usage: %prog [options]",
					   option_list=option_list, 
					   description="Compare two biological conditions with Kallisto and DESeq2.",
					   epilogue="For comments, bug reports etc... please contact STLAb CSIR-IICB")
opt <- parse_args(parser, args=commandArgs(trailingOnly=TRUE), positional_arguments=0)$options



#Check mandetory inputs 
if ( is.null(opt$targetFile) ) {
  stop("--sample groupfile file / target file must be provided. See script usage (--help)")
}

if ( is.null(opt$quantDir) ) {
  stop("--path to the directory containing the Kallisto Quantification files must be provided. See script usage (--help)")
}

if ( is.null(opt$tx2geneDirectory) ) {
  stop("--tx2geneDirectory folder path must be provided. See script usage (--help)")
}
if ( is.null(opt$condRef) ) {
  stop("--reference biological condition name must be provided. See script usage (--help)")
}





# get options and arguments
workDir <- getwd()
projectName <- opt$projectName 
reportName <-opt$reportName                      # name of the project
targetFile <- opt$targetFile 
templateFile <- opt$templateFile                        # path to the design/target file   
tx2geneDirectory <- opt$tx2geneDirectory             # path to the tx2gene Directory
quantDir <- opt$quantDir                             # path to the directory containing salmon quantification files
varInt <- opt$varInt                                 # factor of interest
condRef <- opt$condRef                               # reference biological condition
batch <- opt$batch                                   # blocking factor: NULL (default) or "batch" for example
fitType <- opt$fitType                               # mean-variance relationship: "parametric" (default), "local" or "mean"
alpha <- as.numeric(opt$alpha)                       # threshold of statistical significance
pAdjustMethod <- opt$pAdjustMethod                   # p-value adjustment method: "BH" (default) or "BY"
locfunc <- opt$locfunc                               # "median" (default) or "shorth" to estimate the size factors
				

 print(paste("workDir", workDir))
 print(paste("projectName", projectName))
 print(paste("reportName", reportName))
 print(paste("targetFile", targetFile))
 print(paste("quantDir", quantDir))
 print(paste("varInt", varInt))
 print(paste("condRef", condRef))
 print(paste("batch", batch))
 print(paste("fitType", fitType))
 print(paste("alpha", alpha))
 print(paste("pAdjustMethod", pAdjustMethod))
 print(paste("locfunc", locfunc))

################################################################################
###                             running script                               ###
################################################################################
# setwd(workDir)
#dir.create(projectName, showWarnings = FALSE, recursive = TRUE)

#imageFolder <- paste0(projectName,"/figures/")
#tableFolder <- paste0(projectName,"/tables/")

#dir.create(imageFolder, showWarnings = FALSE, recursive = TRUE)
dir.create("tables", showWarnings = FALSE, recursive = TRUE)


#source("/opt/RNASeqPIPE/tools/utility/load.TargetFile.R")
#source("/opt/RNASeqPIPE/tools/utility/run.DESeq2_trans.r")
#source("/opt/RNASeqPIPE/tools/utility/exportResults.DESeq2.R")

#plots
					   
# loading target file
target <- loadTargetFile(targetFile=targetFile, varInt=varInt, condRef=condRef, batch=batch)
#names(target$files)
print (target)
#loading counts

sampledata = read.table(targetFile, header = TRUE, sep='\t')

print (sampledata)
samplenames = sampledata$samples
print (samplenames)

files <- file.path(quantDir, 'kallisto_quant', target$samples, "abundance.h5")

#print ("file names:",files)

kallisto_dname <- dirname(files)
kallisto_file_names <- basename(kallisto_dname)
names(files) <- kallisto_file_names
print (files)


tx2gene <- read_csv(file.path(tx2geneDirectory, "tx2gene.csv"))

txi.kallisto <- tximport(files, type="kallisto", tx2gene=tx2gene)

countdata <- txi.kallisto$counts 


#Add header (sample names to count data)
#sampledata = read.table(targetFile, header = TRUE)
#samplenames = sampledata[,"label"]
#colnames(countdata) = samplenames
#head(countdata) 



#analysis with DESeq2
out.DESeq2 <- run.DESeq2_trans(counts=txi.kallisto, target=target, varInt=varInt, batch=batch,
                         locfunc=locfunc, fitType=fitType, pAdjustMethod=pAdjustMethod,
                         alpha=alpha)
#####
dds <- out.DESeq2$dds
res <- results(dds)
dds <- dds[ rowSums(counts(dds)) > 0, ]


coldata <- colData(dds)
intgroup<- colnames(coldata[c(2,3)])

#coldata
#intgroup


dds.rld.trans <- rlog(dds, blind=FALSE)


sampleDists <- as.matrix(dist(t(assay(dds.rld.trans))))

####################################################################################
exportResults.DESeq2(out.DESeq2, group=unique(target[,varInt]), alpha=alpha)
####################################################################################

save.image(file=paste0(reportName, ".RData"))

report <- DESeq2Report(dds, projectName, intgroup, outdir = reportName,  output = 'index', nBest = 50000, nBestFeatures = 20, template = templateFile)

if(interactive()) {
    browseURL(report)
}


