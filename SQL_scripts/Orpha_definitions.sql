use orphanet;

# Query 1: repartition of disease types in orphanet, lest cell gives total count
select DisorderType, count(DisorderType) as count from orpha_definitions
group by DisorderType with rollup;

# Query 2 count number of diseases annotated according to the classification level
select  ClassificationLevel, count(Distinct(c.OrphaCode)) as disease_count 
from clinical_annotations c
left join orpha_definitions d on c.OrphaCode=d.OrphaCode
group by ClassificationLevel with rollup;

# shows there are 21 disease for which there are clinical annotations but not disease definitions
# possibly new diseases that have not been included in the export ...alter

# lets drop these from the clinical annotations table

DELETE FROM clinical_annotations
WHERE OrphaCode NOT IN (select OrphaCode from orpha_definitions);

# Query 2 lets rerun to see total number of disordes annotated by class of disorder,
# as we have compared with definitions table it also shows number of diseases annotated tha talso have definition

select COALESCE (ClassificationLevel, 'TOTAL') as classification, count(Distinct(c.OrphaCode)) as disease_count 
from clinical_annotations c
left join orpha_definitions d on c.OrphaCode=d.OrphaCode
group by ClassificationLevel with rollup;
select * from clinical_annotations c
left join orpha_definitions d on c.OrphaCode=d.OrphaCode
where ClassificationLevel is null;

# Query 3, count of unique hpo terms used per speciality

select ClassNames as Speciality, Count_HPO_Terms 
from
	(select ClassNames, count(distinct(HPO_ID)) as Count_HPO_Terms from clinical_annotations c
    left join orpha_diseases d on c.OrphaCode = d.OrphaCode
    group by ClassNames) as subQ;

# Query 4, percentage of HPO terms used in the clinical annotations


select count(distinct(HPO_ID)) as Clinical_Annotations_Total_terms, 
    count(distinct(ID)) as Total_HPO_Terms, 
    count(distinct(HPO_ID)) / count(distinct(ID))  * 100 as Percentage_of_terms_used
    from clinical_annotations 
    right join hpo_ontology on  HPO_ID=ID;

# Query 5: how many times each hpo term occurs in each speciality, and compare to max for that speciality
select HPO_ID, Term as HPO_Name,  count(HPO_ID) as Term_Usage , ClassNames as Speciality,
max(count(HPO_ID)) over (partition by ClassNames) as most_used_term_in_speciality
from clinical_annotations c
join orpha_diseases d on c.OrphaCode= d.OrphaCode
join hpo_ontology h on h.ID = c.HPO_ID
group by HPO_ID, ClassNames
order by speciality;

select * from hpo_ontology;

# Query 6: how many diseases per speciality

select ClassNames as Speciality, count(Distinct(d.OrphaCode)) as DiseaseCount
from orpha_diseases d
left join orpha_definitions def on d.OrphaCode = def.OrphaCode
group by ClassNames
order by DiseaseCount desc;

# Query 7: percentage of all disorders that have a definition

select count(distinct(d.OrphaCode)) as DiseaseCount, 
    count(distinct(def.OrphaCode)) as DefinitionCount, 
    count(distinct(def.OrphaCode)) / count(distinct(d.OrphaCode))  * 100 as Percentage_of_disease_with_definition
    from orpha_diseases d 
    left join orpha_definitions def on  d.OrphaCode=def.OrphaCode