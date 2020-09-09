// GRAPHQL
// Will https://www.youtube.com/watch?v=iyjgOR7nBck


// CONSTRAINTS ON UNIQUENESS SPEED UP MERGING DRAMATICALLY

CREATE CONSTRAINT ON (ipro:InterProFamily) ASSERT ipro.accession IS UNIQUE
CREATE CONSTRAINT ON (go:GoClass) ASSERT go.goid IS UNIQUE
CREATE CONSTRAINT ON (q:PDBStructure) Assert q.pdbid IS UNIQUE
CREATE CONSTRAINT ON (pf:PfamFamily) assert pf.accession is unique


call apoc.load.json("file:///interpro.json") yield value
with value as v
merge (:InterProFamily{ accession:KEYS(v)[0],type:v[KEYS(v)[0]].type,features:v[KEYS(v)[0]].name})

CALL apoc.load.json('file:///interpro-go.json') yield value as go
merge (inode:InterProFamily{accession:go.InterPro})
merge (gonode:GoClass{goid:"GO:"+go.GO})
on create set gonode.annotation = go.GO_annotation
merge (inode)-[:InterProFamily_GoClass_CrossRef{annotation:go.interpro_class}]-(gonode)


call apoc.load.json("file:///pfam-to-interpro-map.json") yield value as entry
with entry.metadata as datum
with datum where datum.integrated is not null
merge (inode:InterProFamily{accession: datum.integrated})
merge (pnode:PfamFamily{accession: datum.accession})
on create set pnode.annotation = datum.annotation
merge (inode)-[:InterProFamily_PfamFamily_CrossRef]-(pnode)

// ----------------------------------------------

// Adding molecules one by one, 
call apoc.load.json("file:///nomenclature/3J79.json") yield value
with value.metadata as metadata, value.polymers as polymers
unwind polymers as polymer
merge (structnode:PDBStructure{pdbid:toUpper(metadata.pdbid)})
merge (subchainnode:Subchain{chainid: polymer.chainid, subchain_of: toUpper(metadata.pdbid)}) // GQL VALIDATION FAILS WITH DUPLICATED FIELS/PROPRETIES : SUBCHAIN_OF
on create set subchainnode += {
    organism    : polymer.Taxonomy.name,
    organism_id : polymer.Taxonomy.id,
    length      : polymer.length,
    rnaprot_type: polymer.type,
    nomenclature: polymer.nomenclature,
    description : polymer.polymerDescription.description}
merge (subchainnode)-[:Is_Subchain_Of{pdbid: structnode.pdbid}]-(structnode)


// Subchains to pfams [belongsto]
call apoc.load.json("file:///nomenclature/3J79.json") yield value
with value.metadata as metadata, value.polymers as polys
unwind polys as polymer
match (subchainnode:Subchain{chainid:polymer.chainid, subchain_of:toUpper(metadata.pdbid)}) //Subchain_of:'x'?
unwind polymer.pfamGroups as pfams
match (pfnode:PfamFamily{accession:pfams})
with pfnode, subchainnode
merge (subchainnode)-[:Belongs_to]-(pfnode) 


// Adding surface ratios
:param pdbid => "6R6G"

call apoc.load.csv("file:///surface_ratios/surface_ratio_"+$pdbid+ ".csv")
yield map 
with map
match (chain:Subchain{subchain_of:$pdbid}) where chain.chainid = map.name
with map, chain
set chain.surface_ratio = map.ratio


//###################################### SHOWTIME


//return all subchains of ..
match (p:PDBStructure{pdbid:'3J9M'})-[]-(s:Subchain{subchain_of:'3J9M'})
with s,p 
match (s)-[q]-(w)
return *


//------------------------------------------------
// return pfams with more than n subchains linking to them
match (p:PfamFamily)
with p,size((p)-[]-(:Subchain)) as chaincount
where chaincount > 30
with p, chaincount 
match (p)-[r]-(q:Subchain)
return * limit 100
// AND INTERPRO CONNECTIOSN

match (p:PfamFamily)
with p,size((p)-[]-(:Subchain)) as chaincount
where chaincount > 25
with p, chaincount 
match (p)-[subchain_rel]-(q:Subchain)
match (p)-[ipro_rel]-(ipro:InterProFamily)
with p,q,subchain_rel, ipro_rel,chaincount, ipro
return * limit 400


// By surface ratio

match (n:Subchain) where n.surface_ratio is not null
with n as chain
with apoc.convert.toFloat(chain.surface_ratio) as d, chain 
where d > 0.7
with d as ratio, chain
match (fam:PfamFamily)-[q]-(chain)
with fam, ratio, chain, q
match (fam)-[p]-(ipro:InterProFamily)
with fam,p,ipro,q,chain,ratio
return chain,q,p,ipro,ratio,fam limit 100;


// Consecutive querying


match (p:PfamFamily)
with p,size((p)-[]-(:Subchain)) as chaincount
where chaincount > 25
with p, chaincount 
match (p)-[subchain_rel]-(q:Subchain)
match (p)-[ipro_rel]-(ipro:InterProFamily)
match (ipro)-[goipro]-(go:GoClass)
with p,q,subchain_rel, ipro_rel,chaincount, ipro, goipro, go
return * limit 400


// Single structure 

match (p:PDBStructure{pdbid:"5NJT"})-[issubchain:Is_Subchain_Of]-(chain:Subchain)
with p,issubchain, chain
return * limit 400;

match (p:PDBStructure{pdbid:"5NJT"})-[issubchain:Is_Subchain_Of]-(chain:Subchain)-[belong:Belongs_to]-(pfam:PfamFamily)-[ifam:InterProFamily_PfamFamily_CrossRef]-(ipro:InterProFamily)-[igo:InterProFamily_GoClass_CrossRef]-(goclass:GoClass)
with p,issubchain, chain, belong, pfam,ifam,ipro,igo,goclass
return * limit 400;

match (p:PDBStructure{pdbid:"5NJT"})-[issubchain:Is_Subchain_Of]-(chain:Subchain)-[belong:Belongs_to]-(pfam:PfamFamily)-[ifam:InterProFamily_PfamFamily_CrossRef]-(ipro:InterProFamily)-[igo:InterProFamily_GoClass_CrossRef]-(goclass:GoClass)
with p,issubchain, chain, belong, pfam,ifam,ipro,igo,goclass
return * limit 400;