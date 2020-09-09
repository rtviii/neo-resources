CREATE CONSTRAINT ON (ipro:InterProFamily) ASSERT ipro.family_id IS UNIQUE
CREATE CONSTRAINT ON (go:GOClass) ASSERT go.class_id IS UNIQUE
CREATE CONSTRAINT ON (q:RibosomeStructure) Assert q._PDBId IS UNIQUE
CREATE CONSTRAINT ON (pf:PFAMFamily) assert pf.family_id is unique
CREATE CONSTRAINT ON (bc:BanClass) assert bc.class_id is unique
// Constraints/

call apoc.load.json("file:///interpro.json") yield value
with value as v
merge (q:InterProFamily{ family_id:KEYS(v)[0],type:v[KEYS(v)[0]].type,description:v[KEYS(v)[0]].name})

// VERIFY THESE ON THE SUBSEQUENT UPDATES
CALL apoc.load.json('file:///interpro-go.json') yield value as go
merge (inode:InterProFamily{family_id:go.InterPro})
merge (gonode:GOClass{go_class:go.GO})
on create set gonode.annotation = go.GO_annotation
merge (inode)-[:mp_InterPro_GO{annotation:go.interpro_class}]-(gonode)

// VERIFY THESE ON THE SUBSEQUENT UPDATES
call apoc.load.json("file:///pfam-to-interpro-map{1-4}.json") yield value as entry
with entry.metadata as datum
with datum where datum.integrated is not null
merge (inode:InterProFamily{family_id: datum.integrated})
merge (pnode:PFAMFamily{family_id: datum.accession, family_type:datum.type})
merge (inode)-[:mp_InterPro_PFAM]-(pnode)


// Adding structs
call apoc.load.json("file:///structs/4UG0.json") yield value
with value.proteinNumber as pnum, value.rRNANumber as rnum, value._PDBId as pdbid, value._organismId as orgid, value.resolution as reso, value.publication as pub, value._species as spec, value
merge (q:RibosomeStructure {proteinNumber:pdbid, rRNANumber:rnum, _PDBId:pdbid, _organismId:orgid, resolution:reso,
publication:pub, _species:spec})
with value,q
unwind value.proteins as protein
with q,protein.nomenclature as nom, protein._PDBChainId as cid, protein._UniprotAccession as uniprot, 
protein.surface_ratio as srat, protein._PDBName as name, protein.description as desc, protein._PFAMFamilies as pfams, value
merge (rp:RibosomalProtein {_PDBChainId:cid,description: desc, nomenclature:nom,_PFAMFamilies: pfams })-[:RibosomalProtein_of]->(q)
on create set rp._UniprotAccession = CASE WHEN uniprot = null then "null" else uniprot END, rp._PDBName= name,rp.surface_ratio= srat
with rp, q, value
unwind rp._PFAMFamilies as pfamils
match (pf:PFAMFamily {family_id:pfamils})
with rp,q,value,pf
merge (rp)-[:Belogns_To]->(pf)
with value,q
unwind value.rnas as rna
with rna._PDBChainId as cid, rna.description as desc,q
merge (s:rRNA{_PDBChainId:cid, description: desc })-[:rRNA_of]->(q)

// call apoc.load.json("file:///structs/4UG0.json") yield value
// with value.proteinNumber as pnum, value.rRNANumber as rnum, value._PDBId as pdbid, value._organismId as orgid, value.resolution as reso, value.publication as pub, value._species as spec, value
// merge (q:RibosomeStructure {proteinNumber:pdbid, rRNANumber:rnum, _PDBId:pdbid, _organismId:orgid, resolution:reso,
// publication:pub, _species:spec})
// with value,q
// unwind value.proteins as protein
// with q,protein.nomenclature as nom, protein._PDBChainId as cid, protein._UniprotAccession as uniprot, 
// protein.surface_ratio as srat, protein._PDBName as name, protein.description as desc, protein._PFAMFamilies as pfams, value
// merge (rp:RibosomalProtein {_PDBChainId:cid,description: desc, nomenclature:nom,_PFAMFamilies: pfams })-[:RibosomalProtein_of]->(q)
// on create set rp._UniprotAccession = CASE WHEN uniprot = null then "null" else uniprot END, rp._PDBName= name,rp.surface_ratio= srat
// with rp, q, value
// unwind rp._PFAMFamilies as pfamils
// return pfamils
// merge (rp)-[:Belogns_To]->(pfamils)
// with value,q
// unwind value.rnas as rna
// with rna._PDBChainId as cid, rna.description as desc,q
// merge (s:rRNA{_PDBChainId:cid, description: desc })-[:rRNA_of]->(q)
// delete all 

match (a:rRNA) match (b:RibosomalProtein) match (c:RibosomeStructure) detach delete a,b,c;
// linking to pfams
match (rp:RibosomalProtein) 
unwind rp.`_PFAMFamilies` as pfams
with pfams, rp.`_PDBChainId` as cid
return cid,pfams limit 100;

// For a nullable property, like "Uniprot accession" use ON CREATE and ON MATCH set 
// call apoc.load.json("file:///structs/3J79.json") yield value
// unwind value.proteins as protein
// with protein.nomenclature as nom, protein._PDBChainId as cid, protein._UniprotAccession as uniprot, 
// protein.surface_ratio as srat, protein._PDBName as name, protein.description as desc, protein._PFAMFamilies as pfams
// merge (p:TESTNODE_RP {cid:cid})
// on create set p.uni = CASE WHEN uniprot = null then "null" else uniprot END
// on match set p.uni = CASE WHEN uniprot = null then "null" else uniprot END

// Adding Ban's Classes from nomencature maps

CALL apoc.load.json('file:///LSUmap.json') yield value as v
with keys(v) as array, v
Unwind(array) as protein
with protein, v[protein].pfamDomainAccession as pfams
unwind(pfams) as pfam
merge (c:BanClass {class_id:protein})
with c, pfam
match (pf:PFAMFamily) where pf.family_id = pfam
with c, pf
merge (pf)-[:Associated_With]-(c)

CALL apoc.load.json('file:///SSUmap.json') yield value as v
with keys(v) as array, v
Unwind(array) as protein
with protein, v[protein].pfamDomainAccession as pfams
unwind(pfams) as pfam
merge (c:BanClass {class_id:protein})
with c, pfam
match (pf:PFAMFamily) where pf.family_id = pfam
with c, pf
merge (pf)-[:Associated_With]-(c)

// return protein, pfam
