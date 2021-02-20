@AbapCatalog.sqlViewName: 'YI_Monitor_T'
@AbapCatalog.compiler.CompareFilter: false
@EndUserText.label: 'Monitoring data'
define view YI_Monitor as select from yekko_ekpo_mon {
    key ebeln as PurachaseOrder,
    key ebelp as LineItemNumber,
        bukrs as CompanyCode,
        bstyp as OrderCategory,
        bsart as DocumentType,
        aedat as CreationDate,
        ernam as CreatedByUser,
        lifnr as VendorNumber,
        ekorg as PurchasingOrganization,
        ekgrp as PurchasingGroup,
        matnr as MaterialNumber,
        werks as Plant,
        lgort as StorageLocation,
        @Semantics.quantity.unitOfMeasure: 'OrderQuantityUnit'
        menge as orderQuantity,
        @Semantics.unitOfMeasure: true
        meins as OrderQuantityUnit,
        @Semantics.amount.currencyCode: 'CurrencyCode'
        netwr as NetAmout,
        @Semantics.currencyCode: true
        waers as CurrencyCode,
        plifz as PlannedDeliveyDays
    }
