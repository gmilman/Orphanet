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


select count(distinct(c.HPO_ID)) as Clinical_Annotations_Total_terms, 
	count(distinct(e.HPO_ID)) as Extracted_Terms_Total, 
    count(distinct(ID)) as Total_HPO_Terms, 
    count(distinct(c.HPO_ID)) / count(distinct(ID))  * 100 as Clinical_annotations_as_percentage_Total_HPO,
    count(distinct(e.HPO_ID)) / count(distinct(ID))  * 100 as Extracted_Terms_as_percentage_Total_HPO,
    count(distinct(e.HPO_ID)) / count(distinct(c.HPO_ID))  * 100 as Extracted_Terms_as_percentage_Clinical_Annotations
    from clinical_annotations c
    right join hpo_ontology h on  c.HPO_ID=ID
    left join extracted_hpo_terms e on e.HPO_ID=ID;
# Query 5a: proportion of extracted hpo terms for each orphac code, 
# that match the very frequent HPO terms for the same disease in the Orphanet clinical annotations
		
        -- for each orphacode (i.e.disease) provide the number of terms extracted, 
		-- the number of extacted terms that match the very frequnt terms in the clinical_annotations
        -- the total number of very frequent terms in the clinical annotations
 
select 	
	e1.OrphaCode, 
    count(e1.HPO_ID) as Total_extracted_terms,
    subq.Matched_Extracted_Terms as Matched_Extracted_Terms,
    subq.Total_Clinical_Annotations as Total_Clinical_Annotations
from  extracted_hpo_terms e1
inner join 
			-- query to count the number of matched terms, against total number of very frequent clinical annotations 
	(select 	
            e.OrphaCode, 
            count(e.HPO_ID) as Matched_Extracted_Terms, 
            sub_clin.Total_Clinical_Annotations as Total_Clinical_Annotations
        from 
            extracted_hpo_terms e
            inner join clinical_annotations c ON e.OrphaCode = c.OrphaCode AND e.HPO_ID = c.HPO_ID AND c.HPO_frequency = 'Very frequent (99-80%)'
            inner join 
						-- query to count the number of very frequent annotations
				(select 
					OrphaCode, 
                    count(distinct(HPO_ID)) as Total_Clinical_Annotations 
                from clinical_annotations 
                where HPO_frequency = 'Very frequent (99-80%)'
                group by OrphaCode) AS sub_clin 
			on e.OrphaCode = sub_clin.OrphaCode
        group by e.OrphaCode, sub_clin.Total_Clinical_Annotations) AS subq 
        ON e1.OrphaCode = subq.OrphaCode
group by e1.OrphaCode, subq.Matched_Extracted_Terms, subq.Total_Clinical_Annotations;

# Query 5b: average number of terms per disease for clinical annotations and extracted terms
select Avg_Extracted_Term_per_Def, Avg_Clinical_Annotations_per_Def
from
	(select sum(HPO_count)/count(Extracted_Orpha_Codes) as Avg_Extracted_Term_per_Def 
	from
		(select e.OrphaCode as Extracted_Orpha_Codes, 
		count(e.HPO_ID) as HPO_count
		from extracted_hpo_terms e
		group by e.OrphaCode) as subq1) as subq2
	cross join  
		(select sum(HPO_count_2)/count(Clinical_Orpha_Codes) as Avg_Clinical_Annotations_per_Def 
		from
			(select c.OrphaCode as Clinical_Orpha_codes, 
			count(c.HPO_ID) as HPO_count_2
			from clinical_annotations c
			group by c.OrphaCode) as subq3) as subq4;


# Query 6: how many times each hpo term occurs in each speciality, and compare to max for that speciality
select HPO_ID, Term as HPO_Name,  count(HPO_ID) as Term_Usage , ClassNames as Speciality,
max(count(HPO_ID)) over (partition by ClassNames) as most_used_term_in_speciality
from clinical_annotations c
join orpha_diseases d on c.OrphaCode= d.OrphaCode
join hpo_ontology h on h.ID = c.HPO_ID
group by HPO_ID, ClassNames
order by speciality;

select * from hpo_ontology;

# Query 7: how many diseases per speciality

select ClassNames as Speciality, count(Distinct(d.OrphaCode)) as DiseaseCount
from orpha_diseases d
left join orpha_definitions def on d.OrphaCode = def.OrphaCode
group by ClassNames
order by DiseaseCount desc;

# Query 8: percentage of all disorders that have a definition

select count(distinct(d.OrphaCode)) as DiseaseCount, 
    count(distinct(def.OrphaCode)) as DefinitionCount, 
    count(distinct(def.OrphaCode)) / count(distinct(d.OrphaCode))  * 100 as Percentage_of_disease_with_definition
    from orpha_diseases d 
    left join orpha_definitions def on  d.OrphaCode=def.OrphaCode