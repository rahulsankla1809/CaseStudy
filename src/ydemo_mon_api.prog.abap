*&---------------------------------------------------------------------*
*& Report  ydemo_mon_api
*&
*&---------------------------------------------------------------------*
REPORT ydemo_mon_api.

*=== Interface for types and constants
INTERFACE lif_types_and_constants.

  TYPES: ty_s_monitor TYPE yekko_ekpo_mon,
         ty_t_monitor TYPE TABLE OF yekko_ekpo_mon.

  CONSTANTS: BEGIN OF sc_constants,
               c_pay_terms_10 TYPE eplif VALUE 10,
               c_table_name   TYPE tabname VALUE 'YEKKO_EKPO_MON',
               c_destination  TYPE rfcdest VALUE 'DEMO_DESTINATION',
               BEGIN OF authentication,
                 c_user_name TYPE string VALUE 'Username',
                 c_password  TYPE string VALUE 'password',
               END OF authentication,
             END OF sc_constants.
ENDINTERFACE.

*=== Creating a singleton class to process the request
CLASS lcl_api_send_json DEFINITION CREATE PRIVATE FINAL.
  PUBLIC SECTION.
    CLASS-METHODS:
      class_constructor,
      get_instance RETURNING VALUE(r_instance) TYPE REF TO lcl_api_send_json.

    METHODS:
      process.

  PRIVATE SECTION.
*=== Internal Data definition
    CLASS-DATA: m_object TYPE REF TO lcl_api_send_json.
    DATA: m_t_monitor       TYPE lif_types_and_constants=>ty_t_monitor,
          m_json_string     TYPE string,
          m_response_type   TYPE string,
          m_response_string TYPE string.

*=== Internal methods for processing
    METHODS:
      get_and_store_data,
      refresh_database_table,
      commit_work,
      lock_table RETURNING VALUE(r_subrc) TYPE syst_subrc,
      unlock_table,
      prepare_json_data,
      send_data_to_api,
      format_response.

ENDCLASS.

CLASS lcl_api_send_json IMPLEMENTATION.
*=== Static constructor call to get create the instance
  METHOD class_constructor.
    m_object = NEW lcl_api_send_json( ).
  ENDMETHOD.

*==== Return the instance.
  METHOD get_instance.
    r_instance = m_object.
  ENDMETHOD.

  METHOD process.
*==== Refresh/Delete the data from the temporary table
    refresh_database_table( ).
*==== Quesry and store data in monitoring table
    get_and_store_data( ).
*==== Prepare the data in JSON format to pass to API
    prepare_json_data( ).
*=== check if we have the data is JSON format
    IF m_json_string IS NOT INITIAL.
*=== send the data to API
      send_data_to_api( ).
    ENDIF.
    IF m_response_string IS NOT INITIAL.
      format_response( ).
    ENDIF.
  ENDMETHOD.
  METHOD get_and_store_data.
*==== Extracting data from the tables as required
    SELECT
      ekko~ebeln,
      ekpo~ebelp,
      ekko~bukrs,
      ekko~bstyp,
      ekko~bsart,
      ekko~aedat,
      ekko~ernam,
      ekko~lifnr,
      ekko~ekorg,
      ekko~ekgrp,
      ekpo~matnr,
      ekpo~werks,
      ekpo~lgort,
      ekpo~menge,
      ekpo~meins,
      ekpo~netwr,
      ekko~waers,
      ekpo~plifz
    FROM ekko INNER JOIN ekpo ON ekko~ebeln EQ ekpo~ebeln
    INTO TABLE @m_t_monitor WHERE ekpo~plifz GT @lif_types_and_constants=>sc_constants-c_pay_terms_10.
    IF sy-subrc IS INITIAL.
      INSERT yekko_ekpo_mon FROM TABLE m_t_monitor.
    ENDIF.
*=== finally commit work and unlock the write lock
    commit_work( ).
    unlock_table( ).
  ENDMETHOD.

  METHOD refresh_database_table.

    IF lock_table( ) IS  INITIAL.
*=== If lock is successful, delete the entire table
      DELETE FROM yekko_ekpo_mon.
    ELSE.
*=== Message or error handling if the table can't be locked

    ENDIF.

  ENDMETHOD.
  METHOD commit_work.
*=== Seal the database
    CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'.
  ENDMETHOD.
  METHOD lock_table.
*=== Default lock is write lock
    CALL FUNCTION 'ENQUEUE_E_TABLE'
      EXPORTING
        tabname        = lif_types_and_constants=>sc_constants-c_table_name
      EXCEPTIONS
        foreign_lock   = 1
        system_failure = 2
        OTHERS         = 3.

    r_subrc  = sy-subrc.
  ENDMETHOD.
  METHOD unlock_table.

    CALL FUNCTION 'DEQUEUE_E_TABLE'
      EXPORTING
        tabname = lif_types_and_constants=>sc_constants-c_table_name.

  ENDMETHOD.

  METHOD prepare_json_data.
***==== Using call transformation to convert internal table to JSON
**    DATA(lo_writer) = cl_sxml_string_writer=>create( type = if_sxml=>co_xt_json ).
**    CALL TRANSFORMATION id SOURCE purchaseorder = m_t_monitor RESULT XML lo_writer.
**
**    DATA(lo_conv) = cl_abap_conv_in_ce=>create( input       = lo_writer->get_output( )
**                                                encoding    = 'UTF-8'
**                                                replacement = '?'
**                                                ignore_cerr = abap_true ).
**
**    CALL METHOD lo_conv->read
**      IMPORTING
**        data = m_json_string.

*==== Using serializer to convert internal table to JSON

    DATA(lo_serializer) = NEW cl_trex_json_serializer( data = m_t_monitor ).
    lo_serializer->serialize( ) .
    m_json_string = lo_serializer->get_data( ) .

  ENDMETHOD.
  METHOD send_data_to_api.

*=== Suppressing the method due to missing configuration

    CHECK 1 = 2.

*=== create the HTTP request from Destination (or can be done via URL also)
    CALL METHOD cl_http_client=>create_by_destination
      EXPORTING
        destination              = lif_types_and_constants=>sc_constants-c_destination
      IMPORTING
        client                   = DATA(lo_client)   "----> TYPE REF TO IF_HTTP_CLIENT
      EXCEPTIONS
        argument_not_found       = 1
        destination_not_found    = 2
        destination_no_authority = 3
        plugin_not_active        = 4
        internal_error           = 5
        OTHERS                   = 6.
    IF sy-subrc IS NOT INITIAL.
*=== implement the error handling and exit
      RETURN.
    ENDIF.

*==== Set the appropriate request method (POST, PUT etc.)
    lo_client->request->set_header_field( name = '~request_method' value = if_http_entity=>co_request_method_post ).

*==== Set the HTTP Protocol
    lo_client->request->set_header_field( name = '~server_protocol' value = 'HTTP/1.1' ).

*==== Set the content type as JSON
    lo_client->request->set_header_field( name = 'Content-Type' value = if_rest_media_type=>gc_appl_json ).

*===== Disable logon screen popup
    lo_client->propertytype_logon_popup = if_http_client=>co_disabled.

*==== Set authorization values to log on (Basic authentication)
    lo_client->authenticate( username = lif_types_and_constants=>sc_constants-authentication-c_user_name
                             password = lif_types_and_constants=>sc_constants-authentication-c_password ).

    lo_client->request->set_cdata( data = m_json_string ).

    lo_client->send( EXCEPTIONS
                      http_communication_failure = 1
                      http_invalid_state = 2 ).
    IF sy-subrc IS NOT INITIAL.
*==== Error handling
      RETURN.
    ENDIF.

    lo_client->receive( EXCEPTIONS
                         http_communication_failure = 1
                         http_invalid_state = 2
                         http_processing_failed = 3 ).

    IF sy-subrc IS NOT INITIAL.
*==== Error handling
      RETURN.
    ENDIF.

*==== Get the response type and response data
    m_response_string = lo_client->response->get_cdata( ).
    m_response_type = lo_client->response->get_content_type( ).

  ENDMETHOD.
  METHOD format_response.
    IF m_response_string IS NOT INITIAL.
      CASE m_response_type.
        WHEN if_rest_media_type=>gc_appl_json.

          DATA(lo_deserialize) = NEW cl_trex_json_deserializer( ).
*          lo_deserialize->deserialize( EXPORTING json = m_response_string importing abap = m_t_data ).

        WHEN OTHERS.
*=== when the response in not JSON or any format that has not be taken care

      ENDCASE.
    ENDIF.
  ENDMETHOD.
ENDCLASS.

START-OF-SELECTION.

  DATA(lo_instance) = lcl_api_send_json=>get_instance( ).

  lo_instance->process( ).
