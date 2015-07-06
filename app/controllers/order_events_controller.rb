class OrderEventsController < ApplicationController
    def checkout
        # Find the shopping cart
        shopping_cart = ShoppingCart.find(params[:cart_id])

        # get balances from BlockIo API
        api_balance = BlockIo.get_address_balance(:addresses => current_user.btc_account.address)
        btc_account_balance = current_user.btc_account.btc_account_balance

        if btc_account_balance && (
            api_balance['data']['available_balance'] &&
            btc_account_balance.available_balance) > params[:total]
            # create order with initial status of pending
            order = Order.create(
                order_total: params[:total], customer_id: shopping_cart.user.id
            )

            # get shopping cart items
            shopping_cart_items = shopping_cart.shopping_cart_items.all

            shopping_cart_items.map { |sci|
                # transfer coins from buyer's address to seller's address
                BlockIo.withdraw_from_addresses(
                    :amounts => sci.item.price,
                    :from_addresses => shopping_cart.user.btc_account.address,
                    :to_addresses => sci.item.user.btc_account.address
                )

                # update seller's balance -  debit item price to available_balance
                seller_balance = BlockIo.get_address_balance(:addresses => sci.item.user.btc_account.address)
                sci.item.user.btc_account.btc_account_balance.update(
                    available_balance: seller_balance['data']['available_balance'],
                    pending_received_balance: seller_balance['data']['pending_received_balance']
                )

                # create order items
                order.order_items.create(
                    item_id: sci.item.id, price: sci.item.price, quantity: sci.quantity
                )
            }

            # update buyer's balance - credit the total amount from buyer's available_balance
            buyer_balance = BlockIo.get_address_balance(:addresses => shopping_cart.user.btc_account.address)
            shopping_cart.user.btc_account.btc_account_balance.update(
                available_balance: buyer_balance['data']['available_balance'],
                pending_received_balance: buyer_balance['data']['pending_received_balance']
            )

            # clear and delete cart
            shopping_cart.clear
            shopping_cart.destroy

            # redirect to orders page
            respond_to do |format|
                flash[:warning] = "You have 15 minutes to check the validity of your cards"
                format.html { redirect_to orders_path }
                format.js
            end
        else
            flash[:error] = "You have insufficient funds."
            redirect_to view_cart_path
        end
    end

    def refund

    end

    def dispute

    end

    def cancel

    end
end